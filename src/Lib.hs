{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeOperators #-}

module Lib
    ( app
    , Config(..)
    ) where

import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as BL
import Control.Concurrent.STM.TChan
import Control.Concurrent.STM.TVar
import Control.Monad
import Control.Monad.Except (ExceptT(..))
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Reader
import Control.Monad.Catch (throwM, try)
import Control.Monad.STM
import Data.Monoid ((<>))
import Data.Proxy (Proxy(..))
import Data.Text
import Network.Wai.Handler.WebSockets (websocketsOr)
import qualified Network.WebSockets as WS
import Prelude hiding (id)
import Servant.API
import Servant.Server
import Servant.Utils.StaticFiles

import qualified DB as DB
import Types

-- | Configuration
data Config = Config
    { db      :: TVar DB.Database
    , msgChan :: TChan MessageType
    }

newtype LemmingHandler a = LemmingHandler { runLemmingHandler :: ReaderT Config IO a }
    deriving ( Functor, Applicative, Monad, MonadReader Config )

type LemmingAPI
  =
      ( "attendee" :>
          (    "create" :> ReqBody '[JSON] Text :> Post '[JSON] Int
          :<|> "list"   :>                         Get  '[JSON] [Attendee]
          )
      )
  :<|>
      ( "agendaitem" :>
          (    "get"  :> ReqBody '[JSON] Int :> Get '[JSON] AgendaItem
          :<|> "list" :>                        Get '[JSON] [AgendaItem]
          )
      )

lemmingServerT :: ServerT LemmingAPI LemmingHandler
lemmingServerT = (createAttendee :<|> listAttendees) :<|> (getAgendaItem :<|> listAgendaItems)
    where
        createAttendee :: Text -> LemmingHandler Int
        createAttendee c = LemmingHandler $ do
            db' <- asks db
            a   <- liftIO $ atomically $ DB.createAttendee c db'
            liftIO (print (c, a))
            wch <- asks msgChan
            liftIO $ atomically $ writeTChan wch (Notify (encode a))
            return $ (id :: Attendee -> Int) a

        listAttendees :: LemmingHandler [Attendee]
        listAttendees = LemmingHandler $ do
            db' <- asks db
            liftIO $ atomically $ DB.listAttendees db'

        getAgendaItem :: Int -> LemmingHandler AgendaItem
        getAgendaItem i = LemmingHandler $ do
            db' <- asks db
            r   <- liftIO $ atomically $ DB.getAgendaItem i db'
            case r of
              Just r' -> return r'
              Nothing -> throwM (err404 { errBody = "An agenda item with id: " <> BL.pack (show i) <> " doesn't exist!" })

        listAgendaItems :: LemmingHandler [AgendaItem]
        listAgendaItems = LemmingHandler $ do
            db' <- asks db
            liftIO $ atomically $ DB.listAgendaItems db'

type WithStaticFilesAPI
  =    LemmingAPI
  :<|> Raw -- Static files

lemmingAPI :: Proxy LemmingAPI
lemmingAPI = Proxy

withStaticFilesAPI :: Proxy WithStaticFilesAPI
withStaticFilesAPI = Proxy

handleWS :: Config -> WS.PendingConnection -> IO ()
handleWS conf req = do
    conn <- WS.acceptRequest req
    WS.forkPingThread conn 30
    as <- liftIO $ atomically $ DB.listAttendees $ db conf
    WS.sendTextData conn (encode as)
    ch <- atomically $ dupTChan (msgChan conf)
    forever $ do
        msg <- atomically $ readTChan ch
        case msg of
          Notify m -> WS.sendTextData conn m

app :: Config -> Application
app conf = websocketsOr
            WS.defaultConnectionOptions
            (handleWS conf)
            (serve
                withStaticFilesAPI
                (((convert conf) `enter` lemmingServerT) :<|> serveDirectoryFileServer "static")
            )
    where
        convert :: Config -> LemmingHandler :~> Handler
        convert c = NT (Handler . ExceptT . try . (`runReaderT` c) . runLemmingHandler)

