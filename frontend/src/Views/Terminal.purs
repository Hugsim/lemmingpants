module Views.Terminal where

import Control.Monad.Aff (Aff)
import Data.Const (Const)
import Data.FoldableWithIndex (foldMapWithIndex)
import Data.Maybe (Maybe(Nothing))
import Data.StrMap (StrMap, empty, insert)
import Debug.Trace (traceA)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Prelude (type (~>), Unit, Void, const, pure, (*>), (<$>), (<>), (=<<))

type State =
  { formState :: StrMap String }

data Query a
  = UpdateField String String a
  | SubmitForm a

component :: forall e. H.Component HH.HTML Query Unit Void (Aff (HA.HalogenEffects e))
component =
  H.component
    { initialState: const { formState: empty }
    , render
    , eval
    , receiver: const Nothing
    }
  where
    -- render :: State -> H.Component HH.HTML Query Unit Void (Aff (HA.HalogenEffects e))
    render state =
      HH.div_
        [ HH.h1_ [HH.text "Terminal"]
        , HH.form
          [ HE.onSubmit (HE.input_ SubmitForm) ]
          [ withLabel HP.InputNumber true  "number" "Number"
          , withLabel HP.InputText   true  "cid"    "CID"
          , withLabel HP.InputText   true  "name"   "Full name"
          , withLabel HP.InputText   false "nick"   "Nickname, if any"
          , HH.p_
            [ HH.input
              [ HP.type_ HP.InputSubmit
              , HP.value "I am attending this meeting!"
              ]
            ]
          ]
        ]

    withLabel :: HP.InputType -> Boolean -> String -> String -> H.HTML Void Query
    withLabel t r id lbl =
      HH.p_
        [ HH.label_
          [ HH.text lbl
          , HH.input
            [ HP.type_ t
            , HP.id_ id
            , HP.required r
            , HE.onValueInput (HE.input (UpdateField id))
            ]
          ]
        ]

    eval :: Query ~> H.HalogenM State Query (Const Void) Void Void (Aff (HA.HalogenEffects e))
    eval =
      case _ of
        UpdateField k v next ->
          H.modify (\s -> s { formState = insert k v s.formState }) *>
          pure next
        SubmitForm next      ->
          (traceA =<< foldMapWithIndex (\k v -> k <> ": " <> v <> "\n") <$> H.gets (\s -> s.formState))
          *> pure next
