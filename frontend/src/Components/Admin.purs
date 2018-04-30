module Components.Admin where

import Components.SpeakerQueue as SQ
import Control.Monad.Aff (Aff)
import Data.Either (Either(..), either, note)
import Data.HTTP.Method (Method(..))
import Data.List as L
import Data.Maybe (Maybe(Nothing, Just))
import Effects (LemmingPantsEffects)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Network.HTTP.StatusCode (StatusCode(..))
import Postgrest (createURL)
import Postgrest as PG
import Prelude (type (~>), Unit, bind, const, id, map, pure, show, unit, (*>), (<>), (==), (>>=))
import Types.Agenda (Agenda, AgendaItem(..))
import Types.Agenda as AG
import Types.Attendee (AttendeeDB)
import Types.Token (Payload(..), Token(..))

type State =
  { agenda    :: Agenda
  , token     :: Token
  , attendees :: AttendeeDB
  }
type Input = State

data Query a
  = PreviousAI       a
  | NextAI           a
  | SQMsg SQ.Message a
  | GotNewState State a

data Message
  = Flash String

component :: forall e. H.Component HH.HTML Query Input Message (Aff (LemmingPantsEffects e))
component =
  H.parentComponent
    { initialState: id
    , render
    , eval
    , receiver: HE.input GotNewState
    }
  where
    render :: State -> H.ParentHTML Query SQ.Query Unit (Aff (LemmingPantsEffects e))
    render state =
      if pl.role == "admin_user"
        then
          HH.div_
            ([ HH.h1_
              [ HH.button
                [ HE.onClick (HE.input_ PreviousAI), HP.id_ "prev-button" ]
                [ HH.text "⇐" ]
              , HH.text (either id id (map (\(AgendaItem a) -> a.title) currentAI))
              , HH.button
                [ HE.onClick (HE.input_ NextAI), HP.id_ "next-button" ]
                [ HH.text "⇒" ]
              ]
            , HH.div [HP.class_ (HH.ClassName "clearfix")] []
            ] <> either
                (const [HH.text "No agenda item => no speaker queue."])
                (\ai@(AgendaItem ai') ->
                  let sqHeight = L.length ai'.speakerQueues in
                  [ HH.p_ [ HH.text ("Speaker queue stack height: " <> show sqHeight) ]
                  , case AG.topSQ ai of
                      Nothing -> HH.text "We have no speaker queues I'm afraid. This shouldn't happen. It happened anyway."
                      Just sq ->
                        HH.slot
                          unit
                          SQ.component
                          { speakerQueue: sq, token: state.token, attendees: state.attendees, agendaItemId: ai'.id, sqHeight }
                          (HE.input SQMsg)
                  ])
                currentAI
            )
        else
          HH.div_
            [ HH.p_
              [ HH.text "Please "
              , HH.a
                  [ HP.href "#login" ]
                  [ HH.text "login"  ]
              , HH.text " to access the admin interface."
              ]
            ]
      where
        currentAI    = AG.getCurrentAI state.agenda
        (Payload pl) = let (Token t) = state.token in t.payload

    eval :: Query ~> H.ParentDSL State Query SQ.Query Unit Message (Aff (LemmingPantsEffects e))
    eval =
      case _ of
        PreviousAI next ->
           step AG.prev *> pure next
        NextAI next ->
          step AG.next *> pure next
        SQMsg (SQ.Flash m) next ->
          H.raise (Flash m) *> pure next
        GotNewState s next ->
          H.put s *> pure next

    step
      :: (Agenda -> Maybe Agenda)
      -> H.HalogenM State Query SQ.Query Unit Message (Aff (LemmingPantsEffects e)) Unit
    step f =
      H.get
        >>= \s ->
            setCurrentAgendaItem ((note "ERROR: Agenda: Out of bounds step." (f s.agenda)) >>= AG.getCurrentAI)

    setCurrentAgendaItem
      :: Either String AgendaItem
      -> H.HalogenM State Query SQ.Query Unit Message (Aff (LemmingPantsEffects e)) Unit
    setCurrentAgendaItem mai =
      case mai of
        Left s ->
          H.raise (Flash s)
        Right (AgendaItem c) -> do
          s <- H.get
          r <- H.liftAff (PG.emptyResponse
                 (createURL "/rpc/set_current_agenda_item")
                 s.token
                 POST
                 {id: c.id})
          case r.status of
            StatusCode 200 ->
              pure unit
            _ ->
              H.raise (Flash "setCurrentAgendaItem -- ERROR! Got a HTTP response we didn't expect! See the console for more information.")
