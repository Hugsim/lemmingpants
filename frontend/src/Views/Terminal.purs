module Views.Terminal where

import Control.Monad.Aff (Aff)
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(Just, Nothing), fromMaybe)
import Data.MediaType (MediaType(..))
import Data.StrMap (lookup)
import Debug.Trace (traceA, traceAnyA)
import Effects (LemmingPantsEffects)
import Forms as F
import Forms.Field (mkField)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Network.HTTP.Affjax as AX
import Network.HTTP.RequestHeader (RequestHeader(..))
import Network.HTTP.StatusCode (StatusCode(..))
import Prelude (type (~>), Unit, bind, discard, pure, unit, (*>), (<>))
import Simple.JSON (writeJSON)

type State = { token :: Maybe String }

data Query a
  = HandleInput (Maybe String) a
  | FormMsg F.Message a

-- | The token, if there is one.
type Input = Maybe String

data Message = Flash String

-- TODO: Form library!

component :: forall e. H.Component HH.HTML Query Input Message (Aff (LemmingPantsEffects e))
component =
  H.parentComponent
    { initialState: \i -> { token: i }
    , render
    , eval
    , receiver
    }
  where
    render :: State -> H.ParentHTML Query F.Query Unit (Aff (LemmingPantsEffects e))
    render state =
      HH.div_
        [ HH.h1_ [HH.text "Terminal"]
        , case state.token of
            Nothing -> HH.p_ [ HH.text "You need to be logged in. Please login!" ]
            Just _  ->
              HH.slot
                unit
                (F.component "I am attending this meeting!"
                  [ mkField "id"   "Number"           [HP.type_ HP.InputNumber, HP.required true]
                  , mkField "cid"  "CID"              [HP.type_ HP.InputText,   HP.required true]
                  , mkField "name" "Full name"        [HP.type_ HP.InputText,   HP.required true]
                  , mkField "nick" "Nickname, if any" [HP.type_ HP.InputText,   HP.required false]
                  ]
                )
                unit
                (HE.input FormMsg)
        ]

    eval :: Query ~> H.HalogenM State Query F.Query Unit Message (Aff (LemmingPantsEffects e))
    eval =
      case _ of
        FormMsg m next      -> do
            case m of
              F.FormSubmitted m' -> do
                token <- H.gets (\s -> s.token)
                case token of
                  Nothing -> H.raise (Flash "You are not logged in. Please login.")
                  Just t  -> do
                    let req = AX.defaultRequest
                    r <- H.liftAff (AX.affjax (
                           req { url     = "http://localhost:3000/attendee"
                               , headers =
                                   req.headers <>
                                     [ ContentType (MediaType "application/json")
                                     , RequestHeader "Authorization" ("Bearer " <> t)
                                     ]
                               , method  = Left POST
                               , content = Just (writeJSON m')
                               }))
                    -- The Location-header contains the new Attendee URL.
                    case r.status of
                      StatusCode 201 -> do -- The `Created` HTTP status code.
                        H.raise (Flash ("Thank you for registering, " <> fromMaybe "ERROR! EXTERMINATE!" (lookup "name" m')))
                      _ ->
                        traceAnyA r *> traceA r.response
                pure next
        -- Have we got a new token?
        HandleInput mt next ->
          H.modify (\s -> s { token = mt })
          *> pure next

    receiver :: Input -> Maybe (Query Unit)
    receiver = HE.input HandleInput
