{-# LANGUAGE TemplateHaskell            #-}

-- | This module defines some utilities for working with Template
-- Haskell, which may be useful for defining 'Tool's, but should be
-- considered internal implementation details of this package.
module Data.API.TH
    ( applicativeE
    , optionalInstanceD
    , funSigD
    , simpleD
    , simpleSigD
    , mkNameText
    , fieldNameE
    , fieldNameVarE
    , typeNameE
    ) where

import           Data.API.Tools.Combinators
import           Data.API.Types

import           Control.Applicative
import           Control.Monad
import qualified Data.Text                      as T
import           Language.Haskell.TH
import           Prelude


-- | Construct an idiomatic expression (an expression in an
-- Applicative context), i.e.
--
-- > app ke []             = ke
-- > app ke [e1,e2,...,en] = ke <$> e1 <*> e2 ... <*> en
applicativeE :: ExpQ -> [ExpQ] -> ExpQ
applicativeE ke es0 =
    case es0 of
      []   -> ke
      e:es -> app' (ke `dl` e) es
  where
    app' e []      = e
    app' e (e':es) = app' (e `st` e') es

    st e1 e2 = appE (appE (varE '(<*>)) e1) e2
    dl e1 e2 = appE (appE (varE '(<$>)) e1) e2


-- | Add an instance declaration for a class, if such an instance does
-- not already exist
optionalInstanceD :: ToolSettings -> Name -> [TypeQ] -> [DecQ] -> Q [Dec]
optionalInstanceD stgs c tqs dqs = do
    ts <- sequence tqs
    ds <- sequence dqs
    exists <- isInstance c ts
    if exists then do when (warnOnOmittedInstance stgs) $ reportWarning $ msg ts
                      return []
              else return [InstanceD [] (foldl AppT (ConT c) ts) ds]
  where
    msg ts = "instance " ++ pprint c ++ " " ++ pprint ts ++ " already exists, so it was not generated"


-- | Construct a TH function with a type signature
funSigD :: Name -> TypeQ -> [ClauseQ] -> Q [Dec]
funSigD n t cs = (\ x y -> [x,y]) <$> sigD n t <*> funD n cs

-- | Construct a simple TH definition
simpleD :: Name -> ExpQ -> Q Dec
simpleD n e = funD n [clause [] (normalB e) []]

-- | Construct a simple TH definition with a type signature
simpleSigD :: Name -> TypeQ -> ExpQ -> Q [Dec]
simpleSigD n t e = funSigD n t [clause [] (normalB e) []]


mkNameText :: T.Text -> Name
mkNameText = mkName . T.unpack


-- | Field name as a string expression
fieldNameE :: FieldName -> ExpQ
fieldNameE = stringE . T.unpack . _FieldName

-- | Field name as a variable
fieldNameVarE :: FieldName -> ExpQ
fieldNameVarE = varE . mkNameText . _FieldName

typeNameE :: TypeName -> ExpQ
typeNameE = stringE . T.unpack . _TypeName
