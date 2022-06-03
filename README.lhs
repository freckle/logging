# Logging

A batteries-included Structured Logging toolkit for writing to a single logging
abstraction in CLI apps and production services in Haskell.

## Example

<!--
```haskell
module Main (module Main) where

import Prelude

import Data.Text (Text)
import Text.Markdown.Unlit ()
```
-->

```haskell
import Logging
import qualified Logging.Settings.Env as Env
```

Throughout your application, you should write against the ubiquitous
`MonadLogger` interface, but using the recently released
[`monad-logger-aeson`][monad-logger-aeson]:

[monad-logger-aeson]: https://jship.github.io/posts/2022-05-17-announcing-monad-logger-aeson/

```haskell
action :: MonadLogger m => m ()
action = do
  logInfo "This is a message sans details"

  logError $ "Something went wrong" :# ["error" .= ("oops" :: Text)]

  logDebug "This won't be seen in default settings"
```

When you run your transformer stack, use `runLoggerLoggingT` with a value that
has a `HasLogger` instance. You can use `withThreadContext` here (or anywhere)
to add details that will appear in all the logged messages within that scope.
Placing one of these at the very top-level can provide details suitable for all
logged messages. The `Logger` type itself has a `HasLogger` instance, and this
minimal example takes advantage of that:

```haskell
runner :: LoggingT IO a -> IO a
runner f = do
  logger <- newLogger =<< Env.parse
  runLoggerLoggingT logger $ withThreadContext ["app" .= ("example" :: Text)] f

main :: IO ()
main = runner action
```

The defaults are good for CLI applications, producing colourful output (if
connected to a terminal device) suitable for a human:

![](files/readme-terminal.png)

`Logging.Settings.Env` uses [`envparse`][envparse] to configure logging. This
means we can adjust `LOG_LEVEL`:

[envparse]: https://hackage.haskell.org/package/envparse

![](files/readme-terminal-debug.png)

In production, you will probably want to set `LOG_DESTINATION=json` and ship
logs to some aggregator like Datadog or Mezmo (formerly LogDNA):

![](files/readme-terminal-json.png)

## More Advanced Usage

## Environment-based Configuration

## Integration with RIO

TODO

## Integration with Amazonka

```hs
data App = App
  { appLogger :: Logger
  , appAWS :: AWS.Env
  }

instance HasLogger App where
  -- ...

runApp :: ReaderT App (LoggingT IO) a -> IO a
runApp f = do
  logger <- newLogger defaultLogSettings
  app <- App logger <$> runLoggerLoggingT logger awsDiscover
  runLoggerLoggingT app $ runReaderT f app

awsDiscover :: (MonadIO m, MonadLoggerIO m) => m AWS.Env
awsDiscover = do
    monadLoggerLog <- askLoggerIO

    env <- liftIO $ AWS.newEnv AWS.discover
    pure $ env
        { AWS.envLogger = \level msg -> do
            monadLoggerLog
                defaultLoc
                "Amazonka"
                (fromLevel level)
                (toLogStr msg)
        }

fromLevel :: AWS.LogLevel -> LogLevel
fromLevel = \case
    AWS.Info -> LevelInfo
    AWS.Error -> LevelError
    AWS.Debug -> LevelDebug
    AWS.Trace -> LevelDebug
```

## Integration with WAI

```hs
import Network.Wai.Middleware.Logging

instance HasLogger App where
  -- ...

waiMiddleware :: App -> Middleware
waiMiddleware app = requestLogger app . defaultMiddlewaresNoLogging
```

## Integration with Warp

```hs
instance HasLogger App where
  -- ...

warpSettings :: App -> Settings
warpSettings app = setOnException onEx $ defaultSettings
  where
    onEx _req ex =
        when (defaultShouldDisplayException ex)
            $ runLoggerLoggingT app
            $ logError
            $ "Warp exception"
            :# ["exception" .= displayException ex]
```

## Integration with Yesod

```hs
import Logging.Logger (getLoggerLoggerSet)

instance HasLogger App where
 -- ...

instance Yesod App where
    -- ...
    makeLogger App {..} = do
        logger <- defaultMakeLogger
        pure $ logger { Y.loggerSet = getLoggerLoggerSet appLogger }

    messageLoggerSource app _logger loc source level msg =
        runLoggerLoggingT app $ monadLoggerLog loc source level msg
```

---

[LICENSE](./LICENSE) | [CHANGELOG](./CHANGELOG.md)
