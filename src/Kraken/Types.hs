module Kraken.Types where

import           Control.Arrow
import           Control.Monad
import           Data.Aeson
import           Data.Aeson.Types
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Base64 as B64
import           Data.Default
import           Data.Hashable
import           Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as H (delete,filter,fromList,keys,map,toList)
import           Data.Maybe
import           Data.Ratio
import           Data.Scientific
import           Data.Text (Text)
import qualified Data.Text as T (concat,intercalate,pack,toLower,unpack)
import           Data.Text.Encoding (decodeUtf8)
import           Data.Time
import           Data.Time.Clock.POSIX
import           Data.Vector ((!))
import           GHC.Generics
import           Servant.API

-----------------------------------------------------------------------------



-----------------------------------------------------------------------------

data Asset = 
    XXBT
  | XETH
  | ZCAD
  | ZEUR
  | ZGBP
  | ZJPY
  | ZUSD
    deriving (Eq,FromJSON,Generic,Ord,Read,Show)

instance Default Asset where
  def = XXBT

instance Hashable Asset

instance ToText Asset where
  toText = T.pack . show

-----------------------------------------------------------------------------

data AssetClass =
    Currency
    deriving (Generic,Show)

instance Default AssetClass where
  def = Currency

instance FromJSON AssetClass where
  parseJSON = withText "class" $ \case
    "currency" -> return Currency
    _          -> fail ""

instance ToText AssetClass where
  toText = T.toLower . T.pack . show

-----------------------------------------------------------------------------

data AssetInfo = AssetInfo
  { assetinfoDisplayDecimals :: Int
  , assetinfoClass :: AssetClass
  , assetinfoDecimals :: Int
  , assetinfoAltName :: Text
  } deriving Show

instance FromJSON AssetInfo where
  parseJSON = withObject "asset info" $ \o -> AssetInfo
    <$> o .: "display_decimals"
    <*> o .: "aclass"
    <*> o .: "decimals"
    <*> o .: "altname"

-----------------------------------------------------------------------------

data AssetOptions = AssetOptions
  { assetClass :: AssetClass
  , assetAssets :: [Asset]
  } deriving Show

instance Default AssetOptions where
  def = AssetOptions Currency []

instance ToFormUrlEncoded AssetOptions where
  toFormUrlEncoded AssetOptions{..} =
    [ ("aclass",toText assetClass) ]
    ++
    [ ("asset",(T.intercalate "," . map toText) assetAssets) | not . null $ assetAssets ]

-----------------------------------------------------------------------------

data AssetPair = AssetPair
  { assetpairBase  :: Asset
  , assetpairQuote :: Asset
  } deriving (Eq,Generic,Hashable,Show)

instance Read AssetPair where
  readsPrec p s | length s >= 8 = do let (bs,qs) = splitAt 4 s
                                     (b,br) <- readsPrec p bs
                                     guard (null br)
                                     (q,qr) <- readsPrec p qs
                                     return (AssetPair b q,qr)
                | otherwise     = []

instance Default AssetPair where
  def = AssetPair XXBT ZUSD

instance ToText AssetPair where
  toText AssetPair{..} = T.concat [ toText assetpairBase
                                  , toText assetpairQuote
                                  ]

-----------------------------------------------------------------------------

data AssetPairInfo = AssetPairInfo
  { assetpairinfoAltName :: Text
  , assetpairinfoBaseAssetClass :: AssetClass
  , assetpairinfoBaseAsset :: Asset
  , assetpairinfoQuoteAssetClass :: AssetClass
  , assetpairinfoQuoteAsset :: Asset
  , assetpairinfoLot :: String -- TBC: enum
  , assetpairinfoPairDecimals :: Int
  , assetpairinfoLotDecimals :: Int
  , assetpairinfoLotMultiplier :: Int
  , assetpairinfoLeverageBuy :: [Scientific]
  , assetpairinfoLeverageSell :: [Scientific]
  , assetpairinfoFees :: [(Scientific,Scientific)]
  , assetpairinfoFeesMaker :: [(Scientific,Scientific)]
  , assetpairinfoFeeVolumeCurrency :: Asset
  , assetpairinfoMarginCall :: Scientific
  , assetpairinfoMarginStop :: Scientific
  } deriving Show

instance FromJSON AssetPairInfo where
  parseJSON = withObject "asset pair info" $ \o -> AssetPairInfo
    <$> o .: "altname"
    <*> o .: "aclass_base"
    <*> o .: "base"
    <*> o .: "aclass_quote"
    <*> o .: "quote"
    <*> o .: "lot"
    <*> o .: "pair_decimals"
    <*> o .: "lot_decimals"
    <*> o .: "lot_multiplier"
    <*> o .: "leverage_buy"
    <*> o .: "leverage_sell"
    <*> o .: "fees"
    <*> o .: "fees_maker"
    <*> o .: "fee_volume_currency"
    <*> o .: "margin_call"
    <*> o .: "margin_stop"

-----------------------------------------------------------------------------

data AssetPairs = AssetPairs
  { unAssetPairs :: HashMap AssetPair AssetPairInfo
  } deriving Show

instance FromJSON AssetPairs where
  parseJSON = parseResult
    >=> parseJSON
    >=> return . AssetPairs . H.fromList . map (first read) . H.toList

-----------------------------------------------------------------------------

data AssetPairOptions = AssetPairOptions
  { assetpairPairs :: [AssetPair]
  } deriving Show

instance Default AssetPairOptions where
  def = AssetPairOptions []

instance ToFormUrlEncoded AssetPairOptions where
  toFormUrlEncoded AssetPairOptions{..} =
    [ ("info","info") ]
    ++
    [ ("pair",(T.intercalate "," . map toText) assetpairPairs) | (not . null) assetpairPairs ]

-----------------------------------------------------------------------------

newtype Assets = Assets
  { unAssets :: HashMap Asset AssetInfo
  } deriving Show

instance FromJSON Assets where
  parseJSON = parseResult
    >=> parseJSON
    >=> return . Assets . H.fromList . map (first read) . H.toList

-----------------------------------------------------------------------------

data ClosedOrdersOptions = ClosedOrdersOptions
  { closedordersIncludeTrades :: Bool
  , closedordersUserRef :: Maybe Text
  , closedordersStart :: Maybe TimeBound
  , closedordersEnd  :: Maybe TimeBound
  , closedordersOffset  :: Maybe Int
  , closedordersCloseTime  :: CloseTime
  } deriving Show

instance Default ClosedOrdersOptions where
  def = ClosedOrdersOptions False Nothing Nothing Nothing Nothing Both

instance ToFormUrlEncoded ClosedOrdersOptions where
  toFormUrlEncoded ClosedOrdersOptions{..} =
    [ ("trades",T.toLower . toText . show $ closedordersIncludeTrades ) ]
    ++
    [ ("userref",r) | Just r <- [closedordersUserRef] ]
    ++
    [("start",toText start) | Just start <- [closedordersStart] ]
    ++
    [("end",toText end) | Just end <- [closedordersEnd] ]
    ++
    [ ("ofs",T.pack . show $ ofs) | Just ofs <- [closedordersOffset] ]
    ++
    [ ("closetime",T.toLower . T.pack . show $ closedordersCloseTime )]

-----------------------------------------------------------------------------

data CloseTime =
    Open
  | Close
  | Both
    deriving (Eq,Enum,Ord,Show)

instance Default CloseTime where
  def = Both

-----------------------------------------------------------------------------

data Config = Config
  { configAPIKey     :: ByteString
  , configPrivateKey :: ByteString
  , configPassword   :: Maybe ByteString
  } deriving Show

instance Default Config where
  def = Config
    { configAPIKey     = ""
    , configPrivateKey = ""
    , configPassword   = Nothing
    }

mkConfig :: ByteString -> ByteString -> Maybe ByteString -> Either String Config
mkConfig ak pk pw = case B64.decode pk of
  Right pkd -> Right $ Config ak pkd pw
  Left  e   -> Left e

-----------------------------------------------------------------------------

type Host = String

-----------------------------------------------------------------------------

data LedgersOptions = LedgersOptions
  { ledgersAssetClass :: AssetClass
  , ledgersAssets :: [Asset]
  , ledgersType :: Maybe LedgerType
  , ledgersStart :: Maybe TimeBound
  , ledgersEnd  :: Maybe TimeBound
  , ledgersOffset  :: Maybe Int  
  } deriving Show

instance Default LedgersOptions where
  def = LedgersOptions Currency [] Nothing Nothing Nothing Nothing

instance ToFormUrlEncoded LedgersOptions where
  toFormUrlEncoded LedgersOptions{..} = 
    [ ("aclass",toText ledgersAssetClass) ]
    ++
    [ ("asset",(T.intercalate "," . map toText) ledgersAssets) | (not . null) ledgersAssets ]
    ++
    [ ("type",toText t) | Just t <- [ledgersType] ]
    ++
    [ ("start",toText start) | Just start <- [ledgersStart] ]
    ++
    [ ("end",toText end) | Just end <- [ledgersEnd] ]
    ++
    [ ("ofs",T.pack . show $ ofs) | Just ofs <- [ledgersOffset] ]

-----------------------------------------------------------------------------

data LedgerType =
    AllLedgerTypes
  | Deposit
  | Withdrawal
  | Trade
  | Margin
    deriving (Enum,Eq,Ord,Show)

instance Default LedgerType where
  def = AllLedgerTypes

instance ToText LedgerType where
  toText AllLedgerTypes = "all"
  toText t = T.toLower . T.pack . show $ t

-----------------------------------------------------------------------------

data OHLC = OHLC
  { ohlcTime :: UTCTime
  , ohlcOpen :: Scientific
  , ohlcHigh :: Scientific
  , ohlcLow :: Scientific
  , ohlcClose :: Scientific
  , ohlcVWAP :: Scientific
  , ohlcVol :: Scientific
  , ohlcNumTrades :: Int
  } deriving Show

instance FromJSON OHLC where
  parseJSON = withArray "OHLC" $ \v -> OHLC
    <$> fmap (posixSecondsToUTCTime . fromInteger) (parseJSON (v ! 0))
    <*> fmap read (parseJSON (v ! 1))
    <*> fmap read (parseJSON (v ! 2))
    <*> fmap read (parseJSON (v ! 3))
    <*> fmap read (parseJSON (v ! 4))
    <*> fmap read (parseJSON (v ! 5))
    <*> fmap read (parseJSON (v ! 6))
    <*> parseJSON (v ! 7) 

-----------------------------------------------------------------------------

data OHLCOptions = OHLCOptions
  { ohlcPair :: AssetPair
  , ohlcIntervalMins :: Int
  , ohlcSince :: Maybe Text
  } deriving Show

instance Default OHLCOptions where
  def = OHLCOptions def 1 Nothing

instance ToFormUrlEncoded OHLCOptions where
  toFormUrlEncoded OHLCOptions{..} =
    [ ("pair",toText ohlcPair)
    , ("interval",T.pack $ show ohlcIntervalMins)
    ]
    ++
    [ ("since",since) | Just since <- [ohlcSince] ]

-----------------------------------------------------------------------------

data OHLCs = OHLCs
  { ohlcsLast :: UTCTime
  , ohlcsOHLCs :: HashMap AssetPair [OHLC]
  } deriving Show

instance FromJSON OHLCs where
  parseJSON = parseResult >=> withObject "OHLCs" (\o -> do
    ohlcsLast <- fmap (posixSecondsToUTCTime . fromInteger) (o .: "last")
    let o' = H.map (parseMaybe (parseJSON :: Value -> Parser [OHLC])) (H.delete "last" o)
    let o'' = (H.map fromJust . H.filter isJust) o'
    let ohlcsOHLCs = (H.fromList . map (first (read . T.unpack)) . H.toList) o''
    return OHLCs{..})

-----------------------------------------------------------------------------

data OpenOrdersOptions = OpenOrdersOptions
  { openordersIncludeTrades :: Bool
  , openordersUserRef :: Maybe Text
  } deriving Show

instance Default OpenOrdersOptions where
  def = OpenOrdersOptions False Nothing

instance ToFormUrlEncoded OpenOrdersOptions where
  toFormUrlEncoded OpenOrdersOptions{..} =
    [ ("trades",T.toLower . toText . show $ openordersIncludeTrades ) ]
    ++
    [ ("userref",toText r) | Just r <- [openordersUserRef] ]

-----------------------------------------------------------------------------

data OpenPositionsOptions = OpenPositionsOptions
  { openpositionsTxnIds :: [Text]
  , openpositionsIncludePL :: Bool
  } deriving Show

instance Default OpenPositionsOptions where
  def = OpenPositionsOptions [] False

instance ToFormUrlEncoded OpenPositionsOptions where
  toFormUrlEncoded OpenPositionsOptions{..} =
    [ ("txid", T.intercalate "," openpositionsTxnIds )
    , ("docalcs",T.toLower . toText . show $ openpositionsIncludePL )
    ]

-----------------------------------------------------------------------------

data OrderBookEntry = OrderBookEntry
  { orderbookentryPrice :: Scientific
  , orderbookentryVol :: Scientific
  , orderbookentryTime :: UTCTime
  } deriving Show

instance FromJSON OrderBookEntry where
  parseJSON = withArray "OrderBookEntry" $ \v -> OrderBookEntry
    <$> fmap read (parseJSON (v ! 0))
    <*> fmap read (parseJSON (v ! 1))
    <*> fmap (posixSecondsToUTCTime . fromInteger) (parseJSON (v ! 2))

-----------------------------------------------------------------------------

data OrderBookOptions = OrderBookOptions
  { orderbookoptionsPair :: AssetPair
  , orderbookoptionsCount :: Maybe Int
  } deriving Show

instance Default OrderBookOptions where
  def = OrderBookOptions def Nothing

instance ToFormUrlEncoded OrderBookOptions where
  toFormUrlEncoded OrderBookOptions{..} = 
    [ ("pair",toText orderbookoptionsPair) ]
    ++
    [ ("count",T.pack (show count)) | Just count <- [orderbookoptionsCount]]

-----------------------------------------------------------------------------

data OrderBook = OrderBook
  { orderbookPair :: AssetPair
  , orderbookBids :: [OrderBookEntry]
  , orderbookAsks :: [OrderBookEntry]
  } deriving Show

instance FromJSON OrderBook where
  parseJSON = parseResult >=> parseJSON >=> withObject "OrderBook" (\o -> do
    let p = head $ H.keys o
    ob <- o .: p
    bs <- ob .: "bids"
    as <- ob .: "asks"
    return $ OrderBook (read $ T.unpack p) bs as)

-----------------------------------------------------------------------------

data OrderDir =
    Buy
  | Sell
    deriving Show

instance FromJSON OrderDir where
  parseJSON (String "b") = return Buy
  parseJSON (String "s") = return Sell
  parseJSON _            = mzero

-----------------------------------------------------------------------------

data OrderType = 
    Market
  | Limit
    deriving Show

instance FromJSON OrderType where
  parseJSON (String "m") = return Market
  parseJSON (String "l") = return Limit
  parseJSON _            = mzero

-----------------------------------------------------------------------------

type Port = Int

-----------------------------------------------------------------------------

data PrivateRequest a = PrivateRequest
  { privaterequestNonce :: Int
  , privaterequestOTP   :: Maybe ByteString
  , privaterequestData  :: a
  }

instance (ToFormUrlEncoded a) => ToFormUrlEncoded (PrivateRequest a) where
  toFormUrlEncoded PrivateRequest{..} = 
    [ ("nonce",T.pack . show $ privaterequestNonce) ]
    ++
    [ ("otp",decodeUtf8 otp) | Just otp <- [privaterequestOTP] ]
    ++
    toFormUrlEncoded privaterequestData

-----------------------------------------------------------------------------

data QueryLedgersOptions = QueryLedgersOptions
  { queryledgersIds :: [Text]
  } deriving Show

instance Default QueryLedgersOptions where
  def = QueryLedgersOptions []

instance ToFormUrlEncoded QueryLedgersOptions where
  toFormUrlEncoded QueryLedgersOptions{..} =
    [ ("txid", T.intercalate "," queryledgersIds) ]

-----------------------------------------------------------------------------

data QueryOrdersOptions = QueryOrdersOptions
  { queryordersIncludeTrades :: Bool
  , queryordersUserRef :: Maybe Text
  , queryordersTxnIds :: [Text]
  } deriving Show

instance Default QueryOrdersOptions where
  def = QueryOrdersOptions False Nothing [""]

instance ToFormUrlEncoded QueryOrdersOptions where
  toFormUrlEncoded QueryOrdersOptions{..} =
    [ ("trades",T.toLower . toText . show $ queryordersIncludeTrades ) ]
    ++
    [ ("userref",toText r) | Just r <- [queryordersUserRef] ]
    ++
    [ ("txid", T.intercalate "," queryordersTxnIds ) ]

-----------------------------------------------------------------------------

data QueryTradesOptions = QueryTradesOptions
  { querytradesTxnIds :: [Text]
  , querytradesIncludeTrades :: Bool
  } deriving Show

instance Default QueryTradesOptions where
  def = QueryTradesOptions [] False

instance ToFormUrlEncoded QueryTradesOptions where
  toFormUrlEncoded QueryTradesOptions{..} =
    [ ("txid", T.intercalate "," querytradesTxnIds ) ]
    ++
    [ ("trades",T.toLower . toText . show $ querytradesIncludeTrades ) ]

-----------------------------------------------------------------------------

data SpreadInfo = SpreadInfo
  { spreadinfoTime :: UTCTime
  , spreadinfoBid :: Scientific
  , spreadinfoAsk :: Scientific
  } deriving Show

instance FromJSON SpreadInfo where
  parseJSON = withArray "SpreadInfo" $ \v -> SpreadInfo
    <$> fmap (posixSecondsToUTCTime . fromInteger) (parseJSON (v ! 0))
    <*> fmap read (parseJSON (v ! 1))
    <*> fmap read (parseJSON (v ! 2))

-----------------------------------------------------------------------------

data SpreadOptions = SpreadOptions
  { spreadPair :: AssetPair
  , spreadSince :: Maybe Text
  } deriving Show

instance Default SpreadOptions where
  def = SpreadOptions def Nothing

instance ToFormUrlEncoded SpreadOptions where
  toFormUrlEncoded SpreadOptions{..} =
    [ ("pair",toText spreadPair)]
    ++
    [ ("since",since) | Just since <- [spreadSince] ]

-----------------------------------------------------------------------------

data Spreads = Spreads
  { spreadsPair :: AssetPair
  , spreadsLast :: UTCTime
  , spreadsSpreads :: [SpreadInfo]
  } deriving Show

instance FromJSON Spreads where
  parseJSON = parseResult >=> withObject "Spreads" (\o -> do
    lt <- (o .: "last") >>= parseJSON
    let l = (posixSecondsToUTCTime . fromInteger) lt
    let (p,ssj) = (head . H.toList . H.delete "last") o
    ss <- parseJSON ssj
    return $ Spreads (read $ T.unpack p) l ss)

-----------------------------------------------------------------------------

data TickerInfo = TickerInfo
  { tickerAskPrice :: Scientific
  , tickerAskVol :: Scientific
  , tickerBidPrice :: Scientific
  , tickerBidVol :: Scientific
  , tickerLastTradePrice :: Scientific
  , tickerLastTradeVol :: Scientific
  , tickerVolToday :: Scientific
  , tickerVol24Hours :: Scientific
  , tickerVWAPToday :: Scientific
  , tickerVWAP24Hours :: Scientific
  , tickerNumTradesToday :: Int
  , tickerNumTrades24Hours :: Int
  , tickerLowToday :: Scientific
  , tickerLow24Hours :: Scientific
  , tickerHighToday :: Scientific
  , tickerHigh24Hours :: Scientific
  , tickerOpen :: Scientific
  } deriving Show

instance FromJSON TickerInfo where
  parseJSON = withObject "ticker info" $ \o -> do
    [tickerAskPrice,_,tickerAskVol] <- (map read) <$> o .: "a"
    [tickerBidPrice,_,tickerBidVol] <- (map read) <$> o .: "b"
    [tickerLastTradePrice,tickerLastTradeVol] <- (map read) <$> o .: "c"
    [tickerVolToday,tickerVol24Hours] <- (map read) <$> o .: "v"
    [tickerVWAPToday,tickerVWAP24Hours] <- (map read) <$> o .: "p"
    [tickerNumTradesToday,tickerNumTrades24Hours] <- o .: "t" :: Parser [Int]
    [tickerLowToday,tickerLow24Hours] <- (map read) <$> o .: "l"
    [tickerHighToday,tickerHigh24Hours] <- (map read) <$> o .: "h"
    tickerOpen <- read <$> o .: "o"
    return TickerInfo{..}

-----------------------------------------------------------------------------

data TickerOptions = TickerOptions
  { tickerPairs :: [AssetPair]
  } deriving Show

instance Default TickerOptions where
  def = TickerOptions []

instance ToFormUrlEncoded TickerOptions where
  toFormUrlEncoded TickerOptions{..} =
    [ ("pair",(T.intercalate "," . map toText) tickerPairs)
    ]

-----------------------------------------------------------------------------

data Ticker = Ticker
  { unTicker :: HashMap AssetPair TickerInfo
  } deriving Show

instance FromJSON Ticker where
  parseJSON = parseResult
    >=> parseJSON
    >=> return . Ticker . H.fromList . map (first read) . H.toList

-----------------------------------------------------------------------------

newtype Time = Time { unTime :: UTCTime } deriving Show

instance FromJSON Time where
  parseJSON x = do
    r <- parseResult x
    (t :: Int) <- r .: "unixtime"
    return . Time . posixSecondsToUTCTime . fromIntegral $ t

-----------------------------------------------------------------------------

data TimeBound =
    DateTime UTCTime
  | TxnId Text
    deriving Show

instance ToText TimeBound where
  toText (DateTime ut) = T.pack . show . utcTimeToPOSIXSeconds $ ut
  toText (TxnId ti) = ti

-----------------------------------------------------------------------------

data TradeBalanceOptions = TradeBalanceOptions
  { tradebalanceAssetClass :: Maybe AssetClass
  , tradebalanceAsset :: Asset
  } deriving Show

instance Default TradeBalanceOptions where
  def = TradeBalanceOptions (Just Currency) ZUSD

instance ToFormUrlEncoded TradeBalanceOptions where
  toFormUrlEncoded TradeBalanceOptions{..} =
    [ ("aclass",toText c) | Just c <- [tradebalanceAssetClass] ]
    ++
    [ ("asset",toText tradebalanceAsset) ]

-----------------------------------------------------------------------------

data TradeInfo = TradeInfo
  { tradeinfoPrice :: Scientific
  , tradeinfoVol :: Scientific
  , tradeinfoTime :: UTCTime
  , tradeinfoDir :: OrderDir
  , tradeinfoType :: OrderType
  , tradeinfoMisc :: Text
  } deriving Show

instance FromJSON TradeInfo where
  parseJSON = withArray "TradeInfo" $ \v -> TradeInfo
    <$> fmap read (parseJSON (v ! 0))
    <*> fmap read (parseJSON (v ! 1))
    <*> fmap (posixSecondsToUTCTime . fromInteger) (parseJSON (v ! 2))
    <*> parseJSON (v ! 3)
    <*> parseJSON (v ! 4)
    <*> parseJSON (v ! 5)

-----------------------------------------------------------------------------

data Trades = Trades
  { tradesPair :: AssetPair
  , tradesLast :: UTCTime
  , tradesTrades :: [TradeInfo]
  } deriving Show

instance FromJSON Trades where
  parseJSON = parseResult >=> withObject "Trades" (\o -> do
    lt <- (o .: "last") >>= parseJSON
    let l = (posixSecondsToUTCTime . fromRational . (% 1000000000) . fromInteger . read) lt
    let (p,tsj) = (head . H.toList . H.delete "last") o
    ts <- parseJSON tsj
    return $ Trades (read $ T.unpack p) l ts)

-----------------------------------------------------------------------------

data TradesHistoryOptions = TradesHistoryOptions
  { tradeshistoryType :: Maybe TradeType
  , tradeshistoryIncludeTrades :: Bool
  , tradeshistoryStart :: Maybe TimeBound
  , tradeshistoryEnd  :: Maybe TimeBound
  , tradeshistoryOffset  :: Maybe Int
  } deriving Show

instance Default TradesHistoryOptions where
  def = TradesHistoryOptions Nothing False Nothing Nothing Nothing

instance ToFormUrlEncoded TradesHistoryOptions where
  toFormUrlEncoded TradesHistoryOptions{..} =
    [ ("type",toText t) | Just t <- [tradeshistoryType] ]
    ++
    [ ("trades",T.toLower . toText . show $ tradeshistoryIncludeTrades ) ]
    ++
    [("start",toText start) | Just start <- [tradeshistoryStart] ]
    ++
    [("end",toText end) | Just end <- [tradeshistoryEnd] ]
    ++
    [ ("ofs",T.pack . show $ ofs) | Just ofs <- [tradeshistoryOffset] ]

-----------------------------------------------------------------------------

data TradesOptions = TradesOptions
  { tradesoptionsPair :: AssetPair
  , tradesoptionsSince :: Maybe Text
  } deriving Show

instance Default TradesOptions where
  def = TradesOptions def Nothing

instance ToFormUrlEncoded TradesOptions where
  toFormUrlEncoded TradesOptions{..} =
    [ ("pair",toText tradesoptionsPair)]
    ++
    [ ("since",since) | Just since <- [tradesoptionsSince] ]

-----------------------------------------------------------------------------

data TradeType =
    AllTradeTypes
  | AnyPosition
  | ClosedPosition
  | ClosingPosition
  | NoPosition
    deriving (Enum,Eq,Ord,Show)

instance Default TradeType where
  def = AllTradeTypes

instance ToText TradeType where
  toText = \case 
    AllTradeTypes   -> "all"
    AnyPosition     -> "any position"
    ClosedPosition  -> "closed position"
    ClosingPosition -> "closing position"
    NoPosition      -> "no position"

-----------------------------------------------------------------------------

data TradeVolumeOptions = TradeVolumeOptions
  { tradevolumeFeePairs :: [AssetPair]
  } deriving Show

instance Default TradeVolumeOptions where
  def = TradeVolumeOptions []

instance ToFormUrlEncoded TradeVolumeOptions where
  toFormUrlEncoded TradeVolumeOptions{..} =
    case tradevolumeFeePairs of 
      [] -> []
      _  -> [ ("pair",(T.intercalate "," . map toText) tradevolumeFeePairs)
            , ("fee-info","true")
            ]

-----------------------------------------------------------------------------

instance ToFormUrlEncoded () where
  toFormUrlEncoded () = []

-----------------------------------------------------------------------------

parseResult :: FromJSON a => Value -> Parser a
parseResult = withObject "result" $ \o -> do
  (e :: [String]) <- o .: "error"
  case e of
    [] -> o .: "result"
    _  -> (fail . concat . map show) e
