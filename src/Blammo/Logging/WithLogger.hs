{-# LANGUAGE CPP #-}

module Blammo.Logging.WithLogger (WithLogger (..), runWithLogger) where

import Prelude

import Blammo.Logging.Logger (HasLogger (..), runLogAction)
import Control.Lens (view)
import Control.Monad.IO.Class (MonadIO (..))
import Control.Monad.IO.Unlift (MonadUnliftIO (..))
import Control.Monad.Logger.Aeson (MonadLogger (..), MonadLoggerIO (..))
import Control.Monad.Reader (MonadReader, ReaderT (ReaderT), asks)

-- | Useful with the @DerivingVia@ language extension to derive
--   'MonadLogger' for your application monad
newtype WithLogger env m a = WithLogger (ReaderT env m a)
  deriving newtype
    (Functor, Applicative, Monad, MonadIO, MonadReader env)

runWithLogger :: env -> WithLogger env m a -> m a
runWithLogger env (WithLogger (ReaderT f)) = f env

instance (MonadIO m, HasLogger env) => MonadLogger (WithLogger env m) where
  monadLoggerLog loc source level msg = do
    logger <- asks (view loggerL)
    runLogAction logger loc source level msg

instance (MonadIO m, HasLogger env) => MonadLoggerIO (WithLogger env m) where
  askLoggerIO = do
    logger <- asks (view loggerL)
    pure $ \loc source level msg ->
      liftIO $ runLogAction logger loc source level msg

#if MIN_VERSION_unliftio_core(0, 1, 1)
instance MonadUnliftIO m => MonadUnliftIO (WithLogger env m) where
  withRunInIO inner =
    WithLogger $ ReaderT $ \r ->
    withRunInIO $ \run ->
    inner (run . runWithLogger r)
#else
instance MonadUnliftIO m => MonadUnliftIO (WithLogger env m) where
  askUnliftIO =
    LoggingT $ ReaderT $ \f ->
    withUnliftIO $ \u ->
    return (UnliftIO (unliftIO u . runWithLogger f))
#endif
