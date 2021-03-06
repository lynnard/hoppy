-- This file is part of Hoppy.
--
-- Copyright 2015-2017 Bryan Gardiner <bog@khumba.net>
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

import Foreign.Hoppy.Generator.Main (defaultMain)
import Foreign.Hoppy.Generator.Spec
import Foreign.Hoppy.Generator.Test.Circular.Flob (flobModule)
import Foreign.Hoppy.Generator.Test.Circular.Flub (flubModule)

{-# ANN module "HLint: ignore Use camelCase" #-}

main :: IO ()
main = defaultMain interfaceResult

interfaceResult :: Either String Interface
interfaceResult =
  interfaceAddHaskellModuleBase ["Foreign", "Hoppy", "Test"] =<<
  interface "test" modules

modules :: [Module]
modules = [flobModule, flubModule]
