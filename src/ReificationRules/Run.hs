{-# LANGUAGE CPP #-}
{-# LANGUAGE TypeOperators, ExistentialQuantification, FlexibleContexts #-}
{-# LANGUAGE ConstraintKinds, StandaloneDeriving #-}
-- Okay
{-# LANGUAGE FlexibleInstances, UndecidableInstances #-}

{-# OPTIONS_GHC -Wall #-}

-- {-# OPTIONS_GHC -fno-warn-unused-imports #-} -- TEMP
-- {-# OPTIONS_GHC -fno-warn-unused-binds   #-} -- TEMP

#define MealyAsFun

----------------------------------------------------------------------
-- |
-- Module      :  Run
-- Copyright   :  (c) 2016 Conal Elliott
-- 
-- Maintainer  :  conal@tabula.com
-- Stability   :  experimental
-- 
-- Run a test: reify, CCC, circuit
----------------------------------------------------------------------

module ReificationRules.Run
  ( go,go',goSep,run,runSep,goM,goM',goMSep
  , goNew, goNew'
  ) where

import Prelude

import Control.Monad (when)

import ReificationRules.Lambda (EP,reifyEP)
import ReificationRules.ToCCC (toCCC)

import Circat.Category (Uncurriable)
import Circat.Circuit (Attr,mkGraph,UU,writeDot,displayDot,unitize',(:>))

import Circat.Netlist (saveAsVerilog)
import Circat.Mealy (Mealy(..))

#if defined MealyAsFun
import Circat.Mealy (asFun)
#else
import Circat.Circuit (MealyC(..),unitizeMealyC)
import Control.Arrow (first)
#endif

ranksep :: Double -> Attr
ranksep n = ("ranksep",show n)

type Okay = Uncurriable (:>) ()

go' :: Okay a => String -> [Attr] -> a -> IO ()
#if defined MealyAsFun
go' = goNew'   -- Tidy up later
#else
go' name attrs f = goM' name attrs (Mealy (first f) ())
#endif
{-# INLINE go' #-}

go :: Okay a => String -> a -> IO ()
go name = go' name []
{-# INLINE go #-}

goSep :: Okay a => String -> Double -> a -> IO ()
goSep name s = go' name [ranksep s]

genVerilog :: Bool
genVerilog = False

genPdf :: Bool
genPdf = True

showPretty :: Bool
showPretty = False

showGraph :: Bool
showGraph = False

-- Run an example: reify, CCC, circuit.
run :: Okay a => String -> [Attr] -> EP a -> IO ()
run name attrs e = do when showPretty $ putStrLn (name ++ " = " ++ show e)
                      outGV name attrs (unitize' (toCCC e))
{-# NOINLINE run #-}

runSep :: Okay a => String -> Double -> EP a -> IO ()
runSep name s = run name [ranksep s]

goNew' :: Okay a => String -> [Attr] -> a -> IO ()
goNew' name attrs f = run name attrs (reifyEP f)
{-# INLINE goNew' #-}

goNew :: Okay a => String -> a -> IO ()
goNew name = goNew' name []
{-# INLINE goNew #-}

-- Diagram and Verilog
outGV :: String -> [Attr] -> UU -> IO ()
outGV name attrs circ =
  do when showGraph $ putStrLn $ "outGV: Graph \n" ++ show g
     writeDot attrs g
     when genPdf $ displayDot ("pdf","") name
     -- displayDot ("svg","") 
     -- displayDot ("png","-Gdpi=200")
     when genVerilog $ saveAsVerilog g
 where
   g = mkGraph name circ
{-# NOINLINE outGV #-}

-- TODO: Move file-saving code from outD and saveVerilog to here.

{--------------------------------------------------------------------
    State machines
--------------------------------------------------------------------}

goM :: Okay (a -> b) => String -> Mealy a b -> IO ()
goM name = goM' name []
{-# INLINE goM #-}

goMSep :: Okay (a -> b) => String -> Double -> Mealy a b -> IO ()
goMSep name s = goM' name [ranksep s]
{-# INLINE goMSep #-}

goM' :: Okay (a -> b) => String -> [Attr] -> Mealy a b -> IO ()
{-# INLINE goM' #-}

#if defined MealyAsFun
goM' name attrs = go' name attrs . asFun
#else

goM' name attrs m = putStrLn ("Compiling " ++ name) >>
                    runM name attrs (reifyMealy m)

-- Reified Mealy machine
data MealyE a b =
  forall s. (GenBuses s, Show s) => MealyE (EP ((a,s) -> (b,s))) s

-- The Show constraint is just for the following Show, which is handy for debugging.
-- (See the 'print' in toMealyC.)
deriving instance Show (MealyE a b)

reifyMealy :: Mealy a b -> MealyE a b
reifyMealy (Mealy f s) = MealyE (reifyEP f) s
{-# INLINE reifyMealy #-}

toMealyC :: MealyE a b -> MealyC a b
toMealyC (MealyE f s) = MealyC (toCCC' f) s

runM :: Okay a => String -> [Attr] -> MealyE a b -> IO ()
runM name attrs e = do print e
                       outGV name attrs (unitizeMealyC (toMealyC e))

-- TODO: When mealyAsArrow works, rewrite goM' via go' instead of vice versa

-- Despite INLINE pragmas, I still have to explicitly tell HERMIT to unfold
-- definitions from this module:
-- 
-- try (any-td (unfold ['go,'go','goM,'goM','reifyMealy]))

-- TODO: Maybe pull unitizeMealyC into toMealyC, renaming to "toMealyU"

#endif

