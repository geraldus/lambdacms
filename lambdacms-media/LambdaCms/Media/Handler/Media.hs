{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE FlexibleContexts    #-}

module LambdaCms.Media.Handler.Media
    ( getMediaAdminIndexR
    , getMediaAdminNewR
    , postMediaAdminNewR
    , getMediaAdminEditR
    , patchMediaAdminEditR
    , deleteMediaAdminEditR
    , patchMediaAdminRenameR
    ) where

import           Data.Text               (pack, unpack)
import qualified Data.Text               as T (concat, split)
import           Data.Time               (getCurrentTime, utctDay)
import           LambdaCms.Core.Settings
import           LambdaCms.Media.Import
import qualified LambdaCms.Media.Message as Msg
import           System.Directory
import           System.FilePath


getMediaAdminIndexR    :: MediaHandler Html
getMediaAdminNewR      :: MediaHandler Html
postMediaAdminNewR     :: MediaHandler Html
getMediaAdminEditR     :: MediaId -> MediaHandler Html
patchMediaAdminEditR   :: MediaId -> MediaHandler Html
deleteMediaAdminEditR  :: MediaId -> MediaHandler Html
patchMediaAdminRenameR :: MediaId -> MediaHandler Html

getMediaAdminIndexR = lift $ do
    can <- getCan
    -- Following line needs +XFlexibleContexts in GHC 7.10+
    let indexItem file mroute = $(widgetFile "index_item")
    (files :: [Entity Media]) <- runDB $ selectList [] []
    adminLayout $ do
        setTitleI Msg.MediaIndex
        $(widgetFile "index")

getMediaAdminNewR = lift $ do
    can <- getCan
    (fWidget, enctype) <- generateFormPost uploadForm
    adminLayout $ do
        setTitleI Msg.NewMedia
        $(widgetFile "new")

postMediaAdminNewR = do
    ((results, fWidget), enctype) <- lift $ runFormPost uploadForm
    case results of
        FormSuccess (fileF, nameF, labelF, descriptionF) -> do
            now <- liftIO getCurrentTime
            (location, ctype) <- upload fileF (unpack nameF)
            _ <- lift . runDB . insert $ Media location ctype labelF descriptionF now
            lift . setMessageI $ Msg.SaveSuccess labelF
            redirect MediaAdminIndexR
        _ -> lift $ do
            can <- getCan
            adminLayout $ do
                setTitleI Msg.NewMedia
                $(widgetFile "new")

getMediaAdminEditR fileId = lift $ do
    can <- getCan
    y <- getYesod
    let sr = unpack $ staticRoot y
    file <- runDB $ get404 fileId
    (fWidget, enctype) <- generateFormPost $ mediaForm file
    (rfWidget, rEnctype) <- generateFormPost . renameForm $ mediaBaseName file
    adminLayout $ do
        setTitleI . Msg.EditMedia $ mediaLabel file
        $(widgetFile "edit")

patchMediaAdminEditR fileId = do
    file <- lift . runDB $ get404 fileId
    ((results, fWidget), enctype) <- lift . runFormPost $ mediaForm file
    case results of
        FormSuccess mf -> do
            _ <- lift $ runDB $ update fileId [MediaLabel =. mediaLabel mf, MediaDescription =. mediaDescription mf]
            lift . setMessageI $ Msg.UpdateSuccess (mediaLabel mf)
            redirect $ MediaAdminEditR fileId
        _ -> lift $ do
            can <- getCan
            y <- getYesod
            let sr = unpack $ staticRoot y
            (rfWidget, rEnctype) <- generateFormPost . renameForm $ mediaBaseName file
            adminLayout $ do
                setTitleI . Msg.EditMedia $ mediaLabel file
                $(widgetFile "edit")

deleteMediaAdminEditR fileId = do
    file <- lift . runDB $ get404 fileId
    isDeleted <- deleteMedia file fileId
    case isDeleted of
        True -> do
            lift . setMessageI $ Msg.DeleteSuccess (mediaLabel file)
            redirect MediaAdminIndexR
        False -> do
            lift . setMessageI $ Msg.DeleteFail (mediaLabel file)
            redirect $ MediaAdminEditR fileId

patchMediaAdminRenameR fileId = do
    file <- lift . runDB $ get404 fileId
    ((results, rfWidget), rEnctype) <- lift . runFormPost . renameForm $ mediaBaseName file
    case results of
        FormSuccess nn
            | nn == (mediaBaseName file) -> do
                lift $ setMessageI Msg.RenameSuccess
                redirect $ MediaAdminEditR fileId
            | otherwise -> do
                isRenamed <- renameMedia file fileId nn
                case isRenamed of
                    True -> do
                        lift $ setMessageI Msg.RenameSuccess
                        redirect $ MediaAdminEditR fileId
                    False -> do
                        lift $ setMessageI Msg.RenameFail
                        redirect $ MediaAdminEditR fileId
        _ -> lift $ do
            can <- getCan
            y <- getYesod
            let sr = unpack $ staticRoot y
            (fWidget, enctype) <- generateFormPost $ mediaForm file
            adminLayout $ do
                setTitleI . Msg.EditMedia $ mediaLabel file
                $(widgetFile "edit")

uploadForm :: MediaForm (FileInfo, Text, Text, Maybe Textarea)
uploadForm = renderBootstrap3 BootstrapBasicForm $ (,,,)
    <$> areq fileField (bfs Msg.Location) Nothing
    <*> areq textField (bfs Msg.NewFilename) Nothing
    <*> areq textField (bfs Msg.Label) Nothing
    <*> aopt textareaField (bfs Msg.Description) Nothing
    <*  bootstrapSubmit (BootstrapSubmit Msg.Upload " btn-success " [])

mediaForm :: Media -> MediaForm Media
mediaForm mf = renderBootstrap3 BootstrapBasicForm $ Media
    <$> pure (mediaLocation mf)
    <*> pure (mediaContentType mf)
    <*> areq textField (bfs Msg.Label) (Just $ mediaLabel mf)
    <*> aopt textareaField (bfs Msg.Description) (Just $ mediaDescription mf)
    <*> pure (mediaUploadedAt mf)
    <*  bootstrapSubmit (BootstrapSubmit Msg.Save " btn-success " [])

renameForm :: Text -> MediaForm Text
renameForm fp = renderBootstrap3 BootstrapBasicForm $
    areq textField (bfs Msg.NewFilename) (Just fp)
    <*  bootstrapSubmit (BootstrapSubmit Msg.Rename " btn-success " [])

upload :: FileInfo -> FilePath -> MediaHandler (FilePath, Text)
upload f nn = do
    y <- lift getYesod
    let filename = unpack $ fileName f
        ctype = fileContentType f
        location = normalise $ (uploadDir y) </> (dropExtension nn) <.> (takeExtension filename)
        path = (staticDir y) </> location
    liftIO . createDirectoryIfMissing True $ dropFileName path
    liftIO $ fileMove f path
    return (location, ctype)

renameMedia :: Media -> MediaId -> Text -> MediaHandler Bool
renameMedia mf fileId nn = do
    y <- lift getYesod
    let clocation = mediaLocation mf
        nlocation = replaceBaseName clocation $ unpack nn
        cpath = (staticDir y) </> clocation
        npath = (staticDir y) </> nlocation
    fileExists <- liftIO $ doesFileExist cpath
    case fileExists of
        True -> do
            liftIO $ renameFile (cpath) (npath)
            _ <- lift . runDB $ update fileId [MediaLocation =. nlocation]
            return True
        False -> return False

deleteMedia :: Media -> MediaId -> MediaHandler Bool
deleteMedia mf fileId = do
    y <- lift getYesod
    let path = (staticDir y) </> (mediaLocation mf)
    fileExists <- liftIO $ doesFileExist path
    case fileExists of
        True -> do
            liftIO $ removeFile path
            fileStillExists <- liftIO $ doesFileExist path
            case fileStillExists of
              True -> return False
              False -> do
                  _ <- lift . runDB $ delete fileId
                  return True
        False -> return True

mediaBaseName :: Media -> Text
mediaBaseName = pack . takeBaseName . mediaLocation

mediaFullLocation :: FilePath -> Media -> FilePath
mediaFullLocation sd = dropTrailingPathSeparator . normalise . (sd </>) . takeDirectory . mediaLocation

splitContentType :: Text -> (Text, Text)
splitContentType ct = (c, t)
    where
        parts = T.split (== '/') ct
        c = head parts
        t = T.concat $ tail parts

isFileType :: Media -> Text -> Bool
isFileType mf t = (fst $ splitContentType $ mediaContentType mf) == t

isImageFile :: Media -> Bool
isImageFile = flip isFileType "image"

isApplicationFile :: Media -> Bool
isApplicationFile = flip isFileType "application"
