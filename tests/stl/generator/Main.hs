-- This file is part of Hoppy.
--
-- Copyright 2015 Bryan Gardiner <bog@khumba.net>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Main (main) where

import Foreign.Hoppy.Generator.Main (run)
import Foreign.Hoppy.Generator.Spec
import Foreign.Hoppy.Generator.Spec.ClassFeature (
  ClassFeature (Assignable, Comparable, Copyable, Equatable),
  classAddFeatures,
  )
import Foreign.Hoppy.Generator.Std (ValueConversion (ConvertPtr, ConvertValue), mod_std)
import Foreign.Hoppy.Generator.Std.String (c_string)
import qualified Foreign.Hoppy.Generator.Std.List as List
import qualified Foreign.Hoppy.Generator.Std.Map as Map
import qualified Foreign.Hoppy.Generator.Std.Pair as Pair
import qualified Foreign.Hoppy.Generator.Std.Set as Set
import qualified Foreign.Hoppy.Generator.Std.Vector as Vector
import System.Environment (getArgs)
import System.Exit (exitFailure)

{-# ANN module "HLint: ignore Use camelCase" #-}

main :: IO ()
main = case interfaceResult of
  Left errorMsg -> do
    putStrLn $ "Error initializing interface: " ++ errorMsg
    exitFailure
  Right iface -> do
    args <- getArgs
    _ <- run [iface] args
    return ()

interfaceResult :: Either String Interface
interfaceResult =
  interfaceAddHaskellModuleBase ["Foreign", "Hoppy", "Test"] =<<
  interface "test" modules

modules :: [Module]
modules = [mod_std, testModule]

testModule :: Module
testModule =
  modifyModule' (makeModule "stl" "stl.hpp" "stl.cpp") $
  addModuleExports $
  concat
  [ [ ExportClass c_IntBox
    , ExportClass c_IntBoxComparable
    , ExportClass c_IntBoxEquatable
    ]
  , List.toExports listInt
  , List.toExports listIntBox
  , List.toExports listIntBoxComparable
  , List.toExports listIntBoxEquatable
  , Map.toExports mapInts
  , Map.toExports mapIntBoxes
  , Pair.toExports pairIntBoxes
  , Set.toExports setInt
  , Set.toExports setIntBox
  , Vector.toExports vectorIntBox
  , Vector.toExports vectorIntBoxComparable
  , Vector.toExports vectorIntBoxEquatable
  , Vector.toExports vectorString
  ]

intBoxInclude :: Include
intBoxInclude = includeLocal "intbox.hpp"

intBoxReqs :: Reqs
intBoxReqs = reqInclude intBoxInclude

-- | This class is deliberately not encodable, in order to ensure that @vector@
-- isn't relying on its value type being encodable.
c_IntBox :: Class
c_IntBox =
  addUseReqs intBoxReqs $
  classAddFeatures [Assignable, Copyable] $
  makeClass (ident "IntBox") Nothing []
  [ mkCtor "new" []
  , mkCtor "newWithValue" [TInt]
  ]
  [ mkConstMethod "get" [] TInt
  , mkMethod "set" [TInt] TVoid
  ]

c_IntBoxComparable :: Class
c_IntBoxComparable =
  addUseReqs intBoxReqs $
  classAddFeatures [Assignable, Comparable, Copyable] $
  makeClass (ident "IntBoxComparable") Nothing [c_IntBox] [] []

c_IntBoxEquatable :: Class
c_IntBoxEquatable =
  addUseReqs intBoxReqs $
  classAddFeatures [Assignable, Copyable, Equatable] $
  makeClass (ident "IntBoxEquatable") Nothing [c_IntBox] [] []

listInt :: List.Contents
listInt =
  List.instantiate' "listInt" TInt mempty $
  List.defaultOptions { List.optValueConversion = Just ConvertValue }

listIntBox :: List.Contents
listIntBox =
  List.instantiate' "listIntBox" (TObj c_IntBox) intBoxReqs $
  List.defaultOptions { List.optValueConversion = Just ConvertPtr }

listIntBoxComparable :: List.Contents
listIntBoxComparable = List.instantiate "listIntBoxComparable" (TObj c_IntBoxComparable) intBoxReqs

listIntBoxEquatable :: List.Contents
listIntBoxEquatable = List.instantiate "listIntBoxEquatable" (TObj c_IntBoxEquatable) intBoxReqs

mapInts :: Map.Contents
mapInts =
  Map.instantiate' "mapInts" TInt TInt intBoxReqs $
  Map.defaultOptions
  { Map.optKeyConversion = Just ConvertValue
  , Map.optValueConversion = Just ConvertValue
  }

mapIntBoxes :: Map.Contents
mapIntBoxes =
  Map.instantiate' "mapIntBoxes" (TObj c_IntBoxComparable) (TObj c_IntBox) intBoxReqs $
  Map.defaultOptions
  { Map.optKeyConversion = Just ConvertPtr
  , Map.optValueConversion = Just ConvertPtr
  }

pairIntBoxes :: Pair.Contents
pairIntBoxes = Pair.instantiate "pairIntBoxes" (TObj c_IntBox) (TObj c_IntBox) intBoxReqs

setInt :: Set.Contents
setInt =
  Set.instantiate' "setInt" TInt intBoxReqs $
  Set.defaultOptions { Set.optValueConversion = Just ConvertValue }

setIntBox :: Set.Contents
setIntBox =
  Set.instantiate' "setIntBox" (TObj c_IntBoxComparable) intBoxReqs $
  Set.defaultOptions { Set.optValueConversion = Just ConvertPtr }

vectorIntBox :: Vector.Contents
vectorIntBox =
  Vector.instantiate' "vectorIntBox" (TObj c_IntBox) intBoxReqs $
  Vector.defaultOptions { Vector.optValueConversion = Just ConvertPtr }

vectorIntBoxComparable :: Vector.Contents
vectorIntBoxComparable = Vector.instantiate "vectorIntBoxComparable" (TObj c_IntBox) intBoxReqs

vectorIntBoxEquatable :: Vector.Contents
vectorIntBoxEquatable = Vector.instantiate "vectorIntBoxEquatable" (TObj c_IntBox) intBoxReqs

vectorString :: Vector.Contents
vectorString =
  Vector.instantiate' "vectorString" (TObj c_string) intBoxReqs $
  Vector.defaultOptions { Vector.optValueConversion = Just ConvertValue }
