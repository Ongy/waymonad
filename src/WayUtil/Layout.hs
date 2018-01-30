{-
waymonad A wayland compositor in the spirit of xmonad
Copyright (C) 2018  Markus Ongyerth

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

Reach us at https://github.com/ongy/waymonad
-}
module WayUtil.Layout
where

import Control.Applicative ((<|>))
import Control.Monad (filterM)
import Control.Monad.IO.Class (liftIO)
import Data.Foldable (toList)
import Data.IORef (readIORef)
import Data.List (find, lookup)
import Data.Maybe (listToMaybe, isJust)
import Foreign.Ptr (Ptr)
import Control.Monad.Trans.Maybe (MaybeT (..))

import Graphics.Wayland.WlRoots.Box (WlrBox (..), Point (..))
import Graphics.Wayland.WlRoots.Output (WlrOutput)

import Output (Output (..), getOutputBox)
import Utility (ptrToInt)
import View (View, getViewEventSurface)
import Waymonad (getSeat, getState)
import Waymonad.Types
import WayUtil (getOutputs)
import {-# SOURCE #-} Input.Seat (getPointerFocus)

import qualified Data.IntMap as IM

viewsBelow :: Foldable t
           => Point
           -> t (View, SSDPrio, WlrBox)
           -> IO [(View, Int, Int)]
viewsBelow (Point x y) views =
    map (uncurry makeLocal) <$> filterM hasSurface (map (\(l, _, r) -> (l, r)) $ toList views)
    where   makeLocal :: View -> WlrBox -> (View, Int, Int)
            makeLocal view (WlrBox bx by _ _) =
                (view, x - bx, y - by)
            hasSurface :: (View, WlrBox) -> IO Bool
            hasSurface (view, WlrBox bx by _ _) = isJust <$> getViewEventSurface view (fromIntegral (x - bx)) (fromIntegral (y - by))


viewBelow :: Point
          -> Output
          -> Way vs a (Maybe (View, Int, Int))
viewBelow point output = do
    let layers = outputLayout output
    let ret = flip fmap layers $ \layer -> MaybeT $ do
            views <- liftIO $ readIORef layer
            candidates <- liftIO $ viewsBelow point views
            seat <- getSeat
            case seat of
                Nothing ->  pure $ listToMaybe candidates
                Just s -> do
                    f <- getPointerFocus s
                    case f of
                        Nothing -> pure $ listToMaybe candidates
                        Just focused ->
                            pure $ find (\(v, _, _) -> v == focused) candidates <|> listToMaybe candidates
    runMaybeT (foldr1 (<|>) ret)


-- | Get the position of the given View on the provided Output.
getViewPosition :: View -> Output -> Way vs ws (Maybe WlrBox)
getViewPosition view Output {outputLayout = layers} = do
    let ret = flip fmap layers $ \layer -> MaybeT $ do
            views <- readIORef layer
            pure $ lookup view $ map (\(l, _, r) -> (l, r)) views
    liftIO $ runMaybeT (foldr1 (<|>) ret)

-- | Get a views position in global layout space
getViewBox :: View -> Way vs ws (Maybe WlrBox)
getViewBox view = do
    outs <- getOutputs
    let mapped = map (\out -> do
            WlrBox px py pw ph <- MaybeT $ getViewPosition view out
            WlrBox ox oy _ _ <- MaybeT $ getOutputBox out
            pure (WlrBox (px + ox) (py + oy) pw ph)
                     ) outs
    runMaybeT $ foldr (<|>) (MaybeT $ pure Nothing) mapped
