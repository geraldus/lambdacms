module LambdaCms.I18n.Italian where

import           Data.Time.Format (TimeLocale(..))
import           Data.Time.Format.Human (HumanTimeLocale (..))
import           LambdaCms.Core.Message (CoreMessage (..))
import           LambdaCms.I18n.Default (defaultHumanTimeLocale)


-- | Italian time locale.
italianTimeLocale :: TimeLocale
italianTimeLocale =  TimeLocale
    {
        wDays  = [("Domenica",  "Do"),  ("Lunedì",   "Lu"),
                  ("Martedì",   "Ma"),  ("Mercoledì","Me"),
                  ("Giovedì",   "Gi"),  ("Venerdì",  "Ve"),
                  ("Sabato",    "Sa")],

        months = [("Gennaio",   "Gen"), ("Febbraio",  "Feb"),
                  ("Marzo",     "Mar"), ("Aprile",    "Apr"),
                  ("Maggio",    "Mag"), ("Giugno",    "Giu"),
                  ("Luglio",    "Lug"), ("Agosto",    "Ago"),
                  ("Settembre", "Set"), ("Ottobre",   "Ott"),
                  ("Novembre",  "Nov"), ("Dicembre",  "Dic")],

        amPm = ("AM", "PM"),
        dateTimeFmt = "%a %b %e %H:%M:%S %Z %Y",
        dateFmt = "%d-%m-%y",
        timeFmt = "%H:%M:%S",
        time12Fmt = "%H:%M:%S",
        knownTimeZones = []
    }

-- | Italian 'HumanTimeLocale'
italianHumanTimeLocale :: (CoreMessage -> String) -> HumanTimeLocale
italianHumanTimeLocale r = (defaultHumanTimeLocale r)
    { locale = italianTimeLocale }
