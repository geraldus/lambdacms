{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module LambdaCms.Media.Foundation where

import Yesod

import LambdaCms.Core

-- import LambdaCms.Media.Models
import LambdaCms.Media.Routes

class LambdaCmsAdmin master => LambdaCmsMedia master where
  uploadDir :: master -> FilePath
  uploadDir _ = "static"

type MediaHandler a = forall master. LambdaCmsMedia master => HandlerT Media (HandlerT master IO) a

type MediaWidget = forall master. LambdaCmsMedia master => WidgetT master IO ()

type Form x = forall master. LambdaCmsMedia master => Html -> MForm (HandlerT Media (HandlerT master IO)) (FormResult x, WidgetT Media IO ())

instance RenderMessage Media FormMessage where
  renderMessage _ _ = defaultFormMessage
