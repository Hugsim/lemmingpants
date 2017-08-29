{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GADTs #-}

module Types
    ( AgendaItem(..)
    , Attendee(..)
    , MessageType(..)
    ) where

import Control.Concurrent.STM.TChan (TChan)
import Data.Aeson
import Data.Monoid
import Data.Text
import qualified Data.Vector as V
import Data.Serialize (Serialize)
import Data.Serialize.Text ()
import Data.Vector.Serialize ()
import GHC.Generics
import qualified Network.WebSockets as WS

-- | Internal stuff for message passing.
data MessageType where
    Notify    :: WS.WebSocketsData a => a -> MessageType

-- Id, CID
data Attendee = Attendee
    { id  :: Int
    , cid :: Text
    } deriving (Generic, Show, Serialize, ToJSON)

data SpeakerQueue = SpeakerQueue
    { speakers :: V.Vector Attendee }
    deriving (Generic, Serialize, ToJSON)

data AgendaItem = AgendaItem
    { id                :: Int
    , title             :: Text
    , content           :: Text
    , speakerQueueStack :: [SpeakerQueue]
    } deriving (Generic, Serialize, ToJSON)

