//+------------------------------------------------------------------+
//|                                XAUUSD_Adaptive_Trend_EA.mq5      |
//|  Research / education reference. Demo-test before any live use.   |
//|  No profit guarantee. Trading leveraged gold can lose all capital.|
//+------------------------------------------------------------------+
#property copyright   "TokiGo quant research"
#property version     "1.00"
#property description "XAUUSD regime-adaptive EA: H4 bias + H1 ADX + M15 pullback/breakout."
#property description "ATR risk sizing, break-even, ATR trailing, daily loss and total-DD guards."
#property description "Not financial advice. Validate on 99% tick data and forward-test on demo."

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerations (must be declared before inputs)                    |
//+------------------------------------------------------------------+
enum ENUM_XAU_RISK_MODE
{
   XAU_RISK_PERCENT = 0,   // Risk % of equity per trade
   XAU_RISK_FIXED   = 1    // Fixed lot size
};

enum ENUM_XAU_ENTRY_MODE
{
   XAU_ENTRY_AUTO     = 0, // AUTO: pullback in normal trend, breakout in strong trend
   XAU_ENTRY_PULLBACK = 1, // Pullback continuation only
   XAU_ENTRY_BREAKOUT = 2, // Range breakout only
   XAU_ENTRY_BOTH     = 3  // Try both engines
};

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== 01. General ==="
input bool                InpEnableTrading        = true;      // Master switch for new trades
input long                InpMagic                = 20261124;  // Magic number (unique per chart)
input string              InpTradeComment         = "XAU-Adaptive";
input int                 InpSlippagePoints       = 50;        // Max slippage (points)
input bool                InpShowPanel            = true;      // Show chart panel
input bool                InpVerboseLog           = true;      // Verbose journal logging

input group "=== 02. Strategy and timeframes ==="
input ENUM_XAU_ENTRY_MODE InpEntryMode            = XAU_ENTRY_AUTO;
input ENUM_TIMEFRAMES     InpBiasTF               = PERIOD_H4;
input ENUM_TIMEFRAMES     InpFilterTF             = PERIOD_H1;
input ENUM_TIMEFRAMES     InpSignalTF             = PERIOD_M15;
input int                 InpEmaFastBias          = 50;        // H4 fast EMA
input int                 InpEmaSlowBias          = 200;       // H4 slow EMA
input int                 InpEmaPullback          = 20;        // M15 pullback EMA
input int                 InpEmaTrend             = 50;        // M15 trend EMA
input int                 InpAdxPeriod            = 14;        // H1 ADX period
input double              InpAdxMin               = 18.0;      // Min H1 ADX for trend trades
input double              InpAdxStrong            = 28.0;      // AUTO switches to breakout above this
input int                 InpRsiPeriod            = 14;        // M15 RSI period
input int                 InpAtrPeriod            = 14;        // M15 ATR period
input int                 InpBreakoutLookback     = 20;        // Donchian lookback (bars)
input double              InpPullbackTolAtr      = 0.25;      // EMA20 touch tolerance (xATR)
input double              InpBreakoutBufferAtr   = 0.10;      // Breakout buffer (xATR)
input double              InpMinBodyAtr           = 0.25;      // Min signal candle body (xATR)
input double              InpMinAtrPercent        = 0.03;      // Min M15 ATR as % of price
input double              InpMaxAtrPercent        = 0.80;      // Max M15 ATR as % of price

input group "=== 03. Risk, stops and exits ==="
input ENUM_XAU_RISK_MODE  InpRiskMode             = XAU_RISK_PERCENT;
input double              InpRiskPercent          = 0.50;      // Risk per trade (% of equity)
input double              InpFixedLot             = 0.01;      // Lot size for fixed mode
input double              InpCommissionPerLot     = 0.0;       // Round-turn commission per lot (account currency)
input double              InpSlAtrMult            = 2.0;       // Initial SL distance (xATR M15)
input double              InpTpAtrMult            = 4.0;       // Take-profit distance (xATR M15)
input bool                InpUseBreakeven         = true;      // Move SL to break-even
input double              InpBreakevenAtR         = 1.0;       // Trigger at +1R
input int                 InpBreakevenOffsetPts   = 10;        // Extra buffer beyond spread (points)
input bool                InpUseTrailing          = true;      // ATR trailing stop
input double              InpTrailStartR          = 1.5;       // Start trailing at +1.5R
input double              InpTrailAtrMult         = 1.5;       // Trail distance (xATR)
input bool                InpUsePartialClose     = false;     // Partial close at +1R
input double              InpPartialAtR           = 1.0;
input double              InpPartialPercent       = 50.0;      // % of position to close
input bool                InpExitOnBiasFlip       = false;     // Close if H4 bias flips
input int                 InpMaxPositions         = 1;         // 1..5
input int                 InpMaxTradesPerDay      = 3;
input double              InpCooldownHoursAfterLoss = 2.0;     // 0 = disabled

input group "=== 04. Hard account guards ==="
input double              InpMaxDailyLossPct      = 2.0;       // Daily equity loss limit (0 = off)
input double              InpDailyProfitTargetPct = 0.0;       // Daily profit target (0 = off)
input bool                InpCloseOnDailyBreach   = true;      // Flatten when a daily limit is hit
input bool                InpUseTotalDDGuard      = true;      // Hard stop from equity high-water mark
input double              InpMaxTotalDDPct        = 10.0;      // Max total equity drawdown %
input bool                InpResetPeakOnInit      = false;     // Reset high-water mark on attach

input group "=== 05. Sessions and execution filters ==="
input bool                InpUseSessionFilter     = true;      // Restrict entries to sessions
input int                 InpSession1StartHour    = 10;        // Server time
input int                 InpSession1EndHour      = 13;
input int                 InpSession2StartHour    = 15;
input int                 InpSession2EndHour      = 20;
input int                 InpFridayCloseHour      = 21;        // Close all Friday after this hour (0 = off)
input double              InpMaxSpreadUsd         = 0.60;      // Max Ask-Bid in USD (0 = no limit)
input bool                InpUseCalendarFilter    = false;     // MT5 economic calendar (USD, high impact)
input string              InpCalendarCurrency     = "USD";
input int                 InpNewsMinutesBefore    = 30;
input int                 InpNewsMinutesAfter     = 30;
input string              InpNewsBlackoutWindows  = "";        // e.g. "1525-1545;2155-2215" (server HHMM)

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
#define XAU_MAX_STATES     64
#define XAU_MAX_BLACKOUTS  16

struct XauPosState
{
   ulong  ticket;
   double initialRisk;
   bool   partialDone;
};

CTrade      g_trade;
XauPosState g_states[XAU_MAX_STATES];
int         g_stateCount = 0;

int g_hEmaFastBias = INVALID_HANDLE;
int g_hEmaSlowBias = INVALID_HANDLE;
int g_hAdxFilter   = INVALID_HANDLE;
int g_hEmaPullback = INVALID_HANDLE;
int g_hEmaTrend    = INVALID_HANDLE;
int g_hAtrSignal   = INVALID_HANDLE;
int g_hRsiSignal   = INVALID_HANDLE;

datetime g_dayStart       = 0;
double   g_dayStartEquity = 0.0;
bool     g_dayBlocked     = false;
int      g_tradesToday    = 0;
datetime g_cooldownUntil  = 0;
double   g_peakEquity     = 0.0;
datetime g_lastPeakSave   = 0;
bool     g_hardBlocked    = false;
ulong    g_lastPanelMs    = 0;
bool     g_warnedMinLot   = false;
ulong    g_unprotectedTicket = 0;
datetime g_lastEmergencyCloseAttempt = 0;
datetime g_lastGuardCloseAttempt = 0;

int g_blackoutStart[XAU_MAX_BLACKOUTS];
int g_blackoutEnd[XAU_MAX_BLACKOUTS];
int g_blackoutCount = 0;

//+------------------------------------------------------------------+
//| Small utilities                                                  |
//+------------------------------------------------------------------+
void Log(const string msg)
{
   if(InpVerboseLog)
      Print("[XAU-EA] ", msg);
}

datetime DayStartOf(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

string PeakKey()
{
   return "XAU_EA_PEAK_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic);
}

string DayEqKey()
{
   return "XAU_EA_DAYEQ_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic);
}

string DayKey()
{
   return "XAU_EA_DAY_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic);
}

string DayBlockKey()
{
   return "XAU_EA_DAYBLOCK_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic);
}

string CooldownKey()
{
   return "XAU_EA_COOL_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic);
}

string RiskKey(const ulong ticket)
{
   return "XAU_EA_RISK_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic) + "_" +
          IntegerToString((long)ticket);
}

string PartialKey(const ulong ticket)
{
   return "XAU_EA_PART_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(InpMagic) + "_" +
          IntegerToString((long)ticket);
}

void PersistDayBlock()
{
   if(!MQLInfoInteger(MQL_TESTER))
      GlobalVariableSet(DayBlockKey(), 1.0);
}

// Keep per-ticket state keys from surviving after their position is gone.
void CleanupTicketKeys()
{
   if(MQLInfoInteger(MQL_TESTER))
      return;

   string suffixBase = IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
                       IntegerToString(InpMagic) + "_";
   string riskPrefix = "XAU_EA_RISK_" + suffixBase;
   string partPrefix = "XAU_EA_PART_" + suffixBase;

   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      string suffix = "";
      if(StringFind(name, riskPrefix) == 0)
         suffix = StringSubstr(name, StringLen(riskPrefix));
      else if(StringFind(name, partPrefix) == 0)
         suffix = StringSubstr(name, StringLen(partPrefix));
      else
         continue;

      ulong ticket = (ulong)StringToInteger(suffix);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         GlobalVariableDel(name);
   }
}

// A deposit/withdrawal is not trading P&L. Shift both equity baselines by
// the cash-flow amount so guards do not mistake it for profit or loss.
void AdjustForCashFlow(const double amount)
{
   if(amount == 0.0)
      return;

   g_dayStartEquity += amount;
   g_peakEquity += amount;
   if(g_dayStartEquity < 0.0)
      g_dayStartEquity = 0.0;
   if(g_peakEquity < 0.0)
      g_peakEquity = 0.0;

   if(!MQLInfoInteger(MQL_TESTER))
   {
      GlobalVariableSet(DayEqKey(), g_dayStartEquity);
      GlobalVariableSet(PeakKey(), g_peakEquity);
   }
   PrintFormat("Cash flow %.2f applied to daily baseline and peak equity.", amount);
}

void SavePeakEquity()
{
   if(MQLInfoInteger(MQL_TESTER))
      return;
   GlobalVariableSet(PeakKey(), g_peakEquity);
}

double SpreadUsd()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

bool SpreadOK()
{
   if(InpMaxSpreadUsd <= 0.0)
      return true;
   double spread = SpreadUsd();
   return (spread > 0.0 && spread <= InpMaxSpreadUsd);
}

double StopsLevelPrice()
{
   return (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
}

double RoundPrice(const double price)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = _Point;
   return NormalizeDouble(MathRound(price / tick) * tick, _Digits);
}

double NormalizeVolume(double volume)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vlimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(vmax <= 0.0)
      vmax = 100.0;
   if(vlimit > 0.0)
      vmax = MathMin(vmax, vlimit);

   volume = MathFloor(volume / step + 1e-9) * step;
   volume = MathMax(vmin, MathMin(vmax, volume));

   // Derive the number of decimals needed to represent the volume step
   // exactly (works for steps such as 0.25, not only powers of ten).
   int digits = 0;
   double scaled = step;
   while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-9)
   {
      scaled *= 10.0;
      digits++;
   }
   return NormalizeDouble(volume, digits);
}

//+------------------------------------------------------------------+
//| Volume sizing                                                    |
//+------------------------------------------------------------------+
double CalcVolume(const double slDistance)
{
   if(InpRiskMode == XAU_RISK_FIXED)
      return NormalizeVolume(InpFixedLot);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * (InpRiskPercent / 100.0);
   if(riskMoney <= 0.0 || slDistance <= 0.0)
      return 0.0;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   // Include the configured round-turn commission so the stop loss does
   // not silently exceed the intended risk percentage.
   double lossPerLot = (slDistance / tickSize) * tickValue + InpCommissionPerLot;
   if(lossPerLot <= 0.0)
      return 0.0;

   double volume = riskMoney / lossPerLot;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   volume = MathFloor(volume / step + 1e-9) * step;

   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(volume < vmin)
   {
      if(!g_warnedMinLot)
      {
         PrintFormat("Risk-based lot %.4f is below broker minimum %.2f. Trade skipped. Increase equity/risk or use fixed lot.",
                     volume, vmin);
         g_warnedMinLot = true;
      }
      return 0.0;
   }
   return NormalizeVolume(volume);
}

bool CheckMargin(const int dir, const double volume, const double price)
{
   double margin = 0.0;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   if(dir < 0)
      orderType = ORDER_TYPE_SELL;
   if(!OrderCalcMargin(orderType, _Symbol, volume, price, margin))
      return false;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   return (margin <= freeMargin * 0.80);
}

//+------------------------------------------------------------------+
//| Position and state helpers                                       |
//+------------------------------------------------------------------+
int PositionCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      count++;
   }
   return count;
}

// Any position on the symbol, regardless of magic. Needed on netting
// accounts, where a new order would merge into an existing manual position.
int SymbolPositionCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      count++;
   }
   return count;
}

double SymbolVolume()
{
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      total += PositionGetDouble(POSITION_VOLUME);
   }
   return total;
}

ulong FindPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      return ticket;
   }
   return 0;
}

ulong FindNewestPositionTicket()
{
   ulong best = 0;
   datetime bestTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(best == 0 || opened >= bestTime)
      {
         best = ticket;
         bestTime = opened;
      }
   }
   return best;
}

bool HasOppositePosition(const int dir)
{
   if(dir == 0)
      return true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if((dir > 0 && type == POSITION_TYPE_SELL) ||
         (dir < 0 && type == POSITION_TYPE_BUY))
         return true;
   }
   return false;
}

bool IsHedgingAccount()
{
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

// Netting/exchange accounts hold one aggregate position per symbol, so
// stacking "positions" is impossible; treat the effective cap as one.
int EffectiveMaxPositions()
{
   if(!IsHedgingAccount())
      return 1;
   return InpMaxPositions;
}

int PositionCountForLimits()
{
   if(!IsHedgingAccount())
      return SymbolPositionCount();
   return PositionCount();
}

ulong LastDealPositionTicket()
{
   ulong deal = g_trade.ResultDeal();
   if(deal == 0)
      return 0;
   if(!HistoryDealSelect(deal))
      return 0;
   long posId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   if(posId <= 0)
      return 0;
   return (ulong)posId;
}

ulong ResolveOpenedTicket()
{
   ulong ticket = LastDealPositionTicket();
   if(ticket > 0 && PositionSelectByTicket(ticket))
      return ticket;
   return FindNewestPositionTicket();
}

void TryCloseUnprotected()
{
   if(g_unprotectedTicket == 0)
      return;
   if(!PositionSelectByTicket(g_unprotectedTicket))
   {
      g_unprotectedTicket = 0;
      return;
   }
   // If a stop was attached manually or by a recovery attempt in the
   // meantime, the emergency close is no longer required.
   if(PositionGetDouble(POSITION_SL) > 0.0)
   {
      g_unprotectedTicket = 0;
      return;
   }

   // Retry every few seconds instead of every tick: the position stays
   // blocked for entries meanwhile, and this avoids hammering the broker
   // (and the journal) with identical close requests on every tick.
   datetime now = TimeCurrent();
   if(g_lastEmergencyCloseAttempt > 0 &&
      (long)now - (long)g_lastEmergencyCloseAttempt < 5)
      return;
   g_lastEmergencyCloseAttempt = now;

   bool sent = g_trade.PositionClose(g_unprotectedTicket);
   uint rc = g_trade.ResultRetcode();
   if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
   {
      PrintFormat("Emergency close succeeded for unprotected position %I64u.", g_unprotectedTicket);
      g_unprotectedTicket = 0;
   }
   else
   {
      PrintFormat("CRITICAL: unprotected position %I64u still open (%u %s). Close it manually.",
                  g_unprotectedTicket,
                  rc,
                  g_trade.ResultRetcodeDescription());
   }
}

int FindState(const ulong ticket)
{
   for(int i = 0; i < g_stateCount; i++)
      if(g_states[i].ticket == ticket)
         return i;
   return -1;
}

void AddState(const ulong ticket, const double risk)
{
   if(g_stateCount >= XAU_MAX_STATES)
   {
      for(int i = 1; i < XAU_MAX_STATES; i++)
         g_states[i - 1] = g_states[i];
      g_stateCount = XAU_MAX_STATES - 1;
   }
   g_states[g_stateCount].ticket      = ticket;
   g_states[g_stateCount].initialRisk = risk;
   g_states[g_stateCount].partialDone = false;
   g_stateCount++;
}

void PruneStates()
{
   int writeIndex = 0;
   for(int i = 0; i < g_stateCount; i++)
   {
      if(PositionSelectByTicket(g_states[i].ticket))
         g_states[writeIndex++] = g_states[i];
      else if(!MQLInfoInteger(MQL_TESTER))
      {
         GlobalVariableDel(RiskKey(g_states[i].ticket));
         GlobalVariableDel(PartialKey(g_states[i].ticket));
      }
   }
   g_stateCount = writeIndex;
}

int CloseAllPositions(const string reason)
{
   int closed = 0;
   int failed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      bool sent = g_trade.PositionClose(ticket);
      uint rc = g_trade.ResultRetcode();
      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
         closed++;
      else
      {
         failed++;
         Log(StringFormat("Close failed for %I64u: %u %s",
                          ticket, rc, g_trade.ResultRetcodeDescription()));
      }
   }
   if(closed > 0)
      PrintFormat("Closed %d position(s): %s", closed, reason);
   if(failed > 0)
      PrintFormat("WARNING: %d position(s) could not be closed (%s). Will retry.", failed, reason);
   return closed;
}

// A guard must keep trying to flatten if the first close attempt is rejected
// (requote, off-quotes, temporary broker restriction). Throttled to 5 seconds.
void RetryGuardClose(const string reason)
{
   if(PositionCount() <= 0)
      return;

   datetime now = TimeCurrent();
   if(g_lastGuardCloseAttempt > 0 &&
      ((long)now - (long)g_lastGuardCloseAttempt) < 5)
      return;
   g_lastGuardCloseAttempt = now;
   CloseAllPositions(reason);
}

int CountTradesToday()
{
   datetime from = DayStartOf(TimeCurrent());
   datetime to   = TimeCurrent() + 1;
   if(from <= 0)
      return 0;
   if(!HistorySelect(from, to))
      return 0;

   int count = 0;
   long seen[256];
   int seenCount = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;

      // A market order can be filled by several IN deals; count the
      // position once rather than treating every partial fill as a trade.
      long posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      if(posId <= 0)
      {
         count++;
         continue;
      }
      bool duplicate = false;
      for(int k = 0; k < seenCount; k++)
      {
         if(seen[k] == posId)
         {
            duplicate = true;
            break;
         }
      }
      if(!duplicate && seenCount < 256)
      {
         seen[seenCount++] = posId;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Day / equity state                                               |
//+------------------------------------------------------------------+
void StartNewDay(const datetime now)
{
   datetime day = DayStartOf(now);
   if(day == g_dayStart && g_dayStartEquity > 0.0)
      return;

   g_dayStart = day;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayBlocked = false;
   g_tradesToday = CountTradesToday();

   if(!MQLInfoInteger(MQL_TESTER))
   {
      string eqKey = DayEqKey();
      string dayKey = DayKey();
      bool sameDay = (GlobalVariableCheck(dayKey) &&
                      (long)GlobalVariableGet(dayKey) == (long)day);

      if(sameDay && GlobalVariableCheck(eqKey))
      {
         g_dayStartEquity = GlobalVariableGet(eqKey);
         if(GlobalVariableCheck(DayBlockKey()) &&
            GlobalVariableGet(DayBlockKey()) > 0.5)
            g_dayBlocked = true;
      }
      else
      {
         g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(eqKey, g_dayStartEquity);
         GlobalVariableSet(dayKey, (double)(long)day);
         GlobalVariableSet(DayBlockKey(), 0.0);
      }
   }
   if(g_dayStartEquity <= 0.0)
   {
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(!MQLInfoInteger(MQL_TESTER))
         GlobalVariableSet(DayEqKey(), g_dayStartEquity);
   }

   Log(StringFormat("New day %s | baseline equity %s | entries today %d",
                    TimeToString(day, TIME_DATE),
                    DoubleToString(g_dayStartEquity, 2),
                    g_tradesToday));
}

void UpdatePeakEquity()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peakEquity)
   {
      g_peakEquity = equity;

      // Persist new highs while the EA is running (throttled), so a terminal
      // crash does not erase the HWM and understate the real drawdown.
      if(!MQLInfoInteger(MQL_TESTER) &&
         (long)TimeCurrent() - (long)g_lastPeakSave >= 60)
      {
         g_lastPeakSave = TimeCurrent();
         SavePeakEquity();
      }
   }
}

//+------------------------------------------------------------------+
//| Environment / session / news filters                             |
//+------------------------------------------------------------------+
bool TradingAllowed()
{
   if(!InpEnableTrading || g_hardBlocked || g_dayBlocked || g_unprotectedTicket > 0)
      return false;

   // Terminal/account permissions are not meaningful inside the Strategy
   // Tester; checking them there can silently block every backtest trade.
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(TerminalInfoInteger(TERMINAL_CONNECTED) == 0)
         return false;
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
         return false;
      if(MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
         return false;
      if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
         return false;
      if(AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0)
         return false;
   }

   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
      return false;
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   return true;
}

bool SymbolAllowsDirection(const int dir)
{
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;
   if(dir > 0 && mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(dir < 0 && mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;
   return true;
}

bool IsWeekend(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

bool InHourWindow(const int minuteOfDay, const int startHour, const int endHour)
{
   if(startHour == endHour)
      return false;
   int start = startHour * 60;
   int end = endHour * 60;
   if(end > start)
      return (minuteOfDay >= start && minuteOfDay < end);
   // Overnight window, e.g. 22:00-02:00.
   return (minuteOfDay >= start || minuteOfDay < end);
}

bool InSession(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int minuteOfDay = dt.hour * 60 + dt.min;

   bool session1 = InHourWindow(minuteOfDay, InpSession1StartHour, InpSession1EndHour);
   bool session2 = InHourWindow(minuteOfDay, InpSession2StartHour, InpSession2EndHour);
   return (session1 || session2);
}

bool FridayCloseDue(const datetime t)
{
   if(InpFridayCloseHour <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour);
}

bool ManualBlackout(const datetime t)
{
   if(g_blackoutCount <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int minuteOfDay = dt.hour * 60 + dt.min;
   for(int i = 0; i < g_blackoutCount; i++)
   {
      int startMin = g_blackoutStart[i];
      int endMin   = g_blackoutEnd[i];
      if(startMin < endMin)
      {
         if(minuteOfDay >= startMin && minuteOfDay < endMin)
            return true;
      }
      else if(startMin > endMin)
      {
         if(minuteOfDay >= startMin || minuteOfDay < endMin)
            return true;
      }
   }
   return false;
}

bool CalendarNewsBlocked(const datetime now)
{
   datetime from = now - (datetime)(InpNewsMinutesAfter * 60);
   datetime to   = now + (datetime)(InpNewsMinutesBefore * 60);

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from, to, NULL, InpCalendarCurrency);
   if(count < 0)
   {
      Log("Calendar data unavailable; news filter skipped this check.");
      return false;
   }
   if(count == 0)
      return false;

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;
      if(event.importance < CALENDAR_IMPORTANCE_HIGH)
         continue;
      datetime eventTime = values[i].time;
      if(now >= eventTime - (datetime)(InpNewsMinutesBefore * 60) &&
         now <= eventTime + (datetime)(InpNewsMinutesAfter * 60))
         return true;
   }
   return false;
}

bool IsEntryWindow(const datetime now)
{
   if(IsWeekend(now))
      return false;
   if(FridayCloseDue(now))
      return false;
   if(InpUseSessionFilter && !InSession(now))
      return false;
   if(ManualBlackout(now))
      return false;
   if(InpUseCalendarFilter && CalendarNewsBlocked(now))
      return false;
   return true;
}

bool ParseHHMM(const string text, int &minutes)
{
   string s = text;
   StringTrimLeft(s);
   StringTrimRight(s);
   int len = StringLen(s);
   if(len < 3 || len > 4)
      return false;

   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(s, i);
      if(c < 48 || c > 57)
         return false;
   }

   long v = StringToInteger(s);
   int h = (int)(v / 100);
   int m = (int)(v % 100);
   if(h < 0 || h > 23 || m < 0 || m > 59)
      return false;

   minutes = h * 60 + m;
   return true;
}

void ParseBlackoutWindows()
{
   g_blackoutCount = 0;
   string raw = InpNewsBlackoutWindows;
   StringTrimLeft(raw);
   StringTrimRight(raw);
   if(StringLen(raw) == 0)
      return;

   string parts[];
   int count = StringSplit(raw, StringGetCharacter(";", 0), parts);
   for(int i = 0; i < count && g_blackoutCount < XAU_MAX_BLACKOUTS; i++)
   {
      string part = parts[i];
      StringTrimLeft(part);
      StringTrimRight(part);
      if(StringLen(part) == 0)
         continue;

      string hm[];
      if(StringSplit(part, StringGetCharacter("-", 0), hm) != 2)
         continue;

      int startMin = 0;
      int endMin = 0;
      if(!ParseHHMM(hm[0], startMin) || !ParseHHMM(hm[1], endMin))
         continue;
      if(startMin == endMin)
         continue;

      g_blackoutStart[g_blackoutCount] = startMin;
      g_blackoutEnd[g_blackoutCount]   = endMin;
      g_blackoutCount++;
   }
   Log(StringFormat("Parsed %d manual news blackout window(s).", g_blackoutCount));
}

//+------------------------------------------------------------------+
//| Indicator access                                                 |
//+------------------------------------------------------------------+
bool GetBufferValue(const int handle, const int buffer, const int shift, double &value)
{
   double tmp[];
   if(CopyBuffer(handle, buffer, shift, 1, tmp) != 1)
      return false;
   value = tmp[0];
   return (value != EMPTY_VALUE);
}

bool DataReady()
{
   if(BarsCalculated(g_hEmaFastBias) < InpEmaSlowBias + 10)
      return false;
   if(BarsCalculated(g_hEmaSlowBias) < InpEmaSlowBias + 10)
      return false;
   if(BarsCalculated(g_hAdxFilter) < InpAdxPeriod + 10)
      return false;
   if(BarsCalculated(g_hEmaPullback) < InpEmaTrend + 10)
      return false;
   if(BarsCalculated(g_hEmaTrend) < InpEmaTrend + 10)
      return false;
   if(BarsCalculated(g_hAtrSignal) < InpAtrPeriod + 10)
      return false;
   if(BarsCalculated(g_hRsiSignal) < InpRsiPeriod + 10)
      return false;
   if(Bars(_Symbol, InpSignalTF) < InpBreakoutLookback + 10)
      return false;
   if(Bars(_Symbol, InpBiasTF) < InpEmaSlowBias + 10)
      return false;
   return true;
}

int GetBias()
{
   double fast[];
   double slow[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);

   if(CopyBuffer(g_hEmaFastBias, 0, 0, 6, fast) != 6)
      return 0;
   if(CopyBuffer(g_hEmaSlowBias, 0, 0, 3, slow) != 3)
      return 0;

   double close1 = iClose(_Symbol, InpBiasTF, 1);
   if(close1 <= 0.0 || fast[1] <= 0.0 || fast[3] <= 0.0 || slow[1] <= 0.0)
      return 0;

   bool up = (close1 > slow[1] && fast[1] > slow[1] && fast[1] > fast[3]);
   bool down = (close1 < slow[1] && fast[1] < slow[1] && fast[1] < fast[3]);

   if(up && !down)
      return 1;
   if(down && !up)
      return -1;
   return 0;
}

bool GetAdx(double &adx, double &diPlus, double &diMinus)
{
   double mainLine[];
   double plusLine[];
   double minusLine[];
   ArraySetAsSeries(mainLine, true);
   ArraySetAsSeries(plusLine, true);
   ArraySetAsSeries(minusLine, true);

   if(CopyBuffer(g_hAdxFilter, 0, 0, 3, mainLine) != 3)
      return false;
   if(CopyBuffer(g_hAdxFilter, 1, 0, 3, plusLine) != 3)
      return false;
   if(CopyBuffer(g_hAdxFilter, 2, 0, 3, minusLine) != 3)
      return false;

   adx     = mainLine[1];
   diPlus  = plusLine[1];
   diMinus = minusLine[1];
   return (adx > 0.0 && diPlus >= 0.0 && diMinus >= 0.0);
}

//+------------------------------------------------------------------+
//| Signals                                                          |
//+------------------------------------------------------------------+
int SignalPullback(const int bias, const double atr)
{
   double ema20 = 0.0;
   double ema50 = 0.0;
   double rsi   = 0.0;
   if(!GetBufferValue(g_hEmaPullback, 0, 1, ema20))
      return 0;
   if(!GetBufferValue(g_hEmaTrend, 0, 1, ema50))
      return 0;
   if(!GetBufferValue(g_hRsiSignal, 0, 1, rsi))
      return 0;
   if(ema20 <= 0.0 || ema50 <= 0.0 || atr <= 0.0)
      return 0;

   double open1  = iOpen(_Symbol, InpSignalTF, 1);
   double close1 = iClose(_Symbol, InpSignalTF, 1);
   double high1  = iHigh(_Symbol, InpSignalTF, 1);
   double low1   = iLow(_Symbol, InpSignalTF, 1);
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return 0;

   double body = MathAbs(close1 - open1);
   if(body < InpMinBodyAtr * atr)
      return 0;

   double tolerance = InpPullbackTolAtr * atr;

   if(bias > 0)
   {
      if(ema20 > ema50 &&
         low1 <= ema20 + tolerance &&
         close1 > ema20 && close1 > ema50 &&
         close1 > open1 &&
         rsi >= 40.0 && rsi <= 70.0)
         return 1;
   }
   else if(bias < 0)
   {
      if(ema20 < ema50 &&
         high1 >= ema20 - tolerance &&
         close1 < ema20 && close1 < ema50 &&
         close1 < open1 &&
         rsi >= 30.0 && rsi <= 60.0)
         return -1;
   }
   return 0;
}

int SignalBreakout(const int bias, const double atr)
{
   double rsi = 0.0;
   if(!GetBufferValue(g_hRsiSignal, 0, 1, rsi))
      return 0;

   double open1  = iOpen(_Symbol, InpSignalTF, 1);
   double close1 = iClose(_Symbol, InpSignalTF, 1);
   if(open1 <= 0.0 || close1 <= 0.0 || atr <= 0.0)
      return 0;

   double body = MathAbs(close1 - open1);
   if(body < InpMinBodyAtr * atr)
      return 0;

   if(bias > 0)
   {
      int index = iHighest(_Symbol, InpSignalTF, MODE_HIGH, InpBreakoutLookback, 2);
      if(index < 0)
         return 0;
      double rangeHigh = iHigh(_Symbol, InpSignalTF, index);
      if(rangeHigh <= 0.0)
         return 0;
      if(close1 > rangeHigh + InpBreakoutBufferAtr * atr &&
         close1 > open1 &&
         rsi > 50.0 && rsi < 85.0)
         return 1;
   }
   else if(bias < 0)
   {
      int index = iLowest(_Symbol, InpSignalTF, MODE_LOW, InpBreakoutLookback, 2);
      if(index < 0)
         return 0;
      double rangeLow = iLow(_Symbol, InpSignalTF, index);
      if(rangeLow <= 0.0)
         return 0;
      if(close1 < rangeLow - InpBreakoutBufferAtr * atr &&
         close1 < open1 &&
         rsi < 50.0 && rsi > 15.0)
         return -1;
   }
   return 0;
}

int GetSignal(const int bias, const double adx, const double atr)
{
   bool tryPullback = false;
   bool tryBreakout = false;

   if(InpEntryMode == XAU_ENTRY_PULLBACK)
      tryPullback = true;
   else if(InpEntryMode == XAU_ENTRY_BREAKOUT)
      tryBreakout = true;
   else if(InpEntryMode == XAU_ENTRY_BOTH)
   {
      tryPullback = true;
      tryBreakout = true;
   }
   else
   {
      tryPullback = (adx < InpAdxStrong);
      tryBreakout = (adx >= InpAdxStrong);
   }

   int signal = 0;
   if(tryBreakout)
      signal = SignalBreakout(bias, atr);
   if(signal == 0 && tryPullback)
      signal = SignalPullback(bias, atr);
   if(signal == 0 && InpEntryMode == XAU_ENTRY_AUTO)
   {
      if(tryBreakout)
         signal = SignalPullback(bias, atr);
      else
         signal = SignalBreakout(bias, atr);
   }
   return signal;
}

//+------------------------------------------------------------------+
//| Execution                                                        |
//+------------------------------------------------------------------+
bool OpenTrade(const int dir, const double atr)
{
   if(dir == 0)
      return false;

   // Netting-account safety: never send an opposite order that would
   // silently close/reverse an existing position.
   if(HasOppositePosition(dir))
   {
      Log("Opposite position exists; entry skipped for netting/hedging safety.");
      return false;
   }

   // On netting/exchange accounts an additional same-direction order would
   // merge into one aggregate position and multiply risk invisibly.
   if(!IsHedgingAccount() && SymbolPositionCount() > 0)
   {
      Log("Netting/exchange account already has a position on this symbol (EA or manual); additional entry skipped.");
      return false;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   double spread = ask - bid;
   if(InpMaxSpreadUsd > 0.0 && (spread <= 0.0 || spread > InpMaxSpreadUsd))
   {
      Log("Spread widened before execution; entry skipped.");
      return false;
   }

   double entryPrice = (dir > 0 ? ask : bid);
   // For a BUY the SL is checked against Bid, and for a SELL against Ask.
   // Therefore the minimum entry-to-SL distance must cover both the broker
   // stops level and the current spread; otherwise INVALID_STOPS is likely
   // on brokers with a non-zero stops level.
   double minDistance = StopsLevelPrice() + spread + _Point * 3.0;

   double slDistance = InpSlAtrMult * atr;
   if(slDistance < minDistance)
      slDistance = minDistance;

   double tpDistance = InpTpAtrMult * atr;
   if(tpDistance < minDistance * 1.5)
      tpDistance = minDistance * 1.5;

   double sl = (dir > 0 ? entryPrice - slDistance : entryPrice + slDistance);
   double tp = (dir > 0 ? entryPrice + tpDistance : entryPrice - tpDistance);
   sl = RoundPrice(sl);
   tp = RoundPrice(tp);

   double volume = CalcVolume(slDistance);
   if(volume <= 0.0)
      return false;

   // Respect the broker's aggregate volume limit before sending the order;
   // otherwise a valid lot can still be rejected on hedging accounts.
   double volLimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(volLimit > 0.0 && SymbolVolume() + volume > volLimit + 1e-9)
   {
      Log("Broker volume limit would be exceeded; entry skipped.");
      return false;
   }

   if(!CheckMargin(dir, volume, entryPrice))
   {
      Log("Margin check failed; trade skipped.");
      return false;
   }

   ulong openedTicket = 0;
   bool sent = false;
   if(dir > 0)
      sent = g_trade.Buy(volume, _Symbol, 0.0, sl, tp, InpTradeComment);
   else
      sent = g_trade.Sell(volume, _Symbol, 0.0, sl, tp, InpTradeComment);

   uint retcode = g_trade.ResultRetcode();
   bool done = (sent && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL));
   if(done)
      openedTicket = ResolveOpenedTicket();

   // Some brokers reject SL/TP on market entry. Open first, then attach stops.
   if(!done && retcode == TRADE_RETCODE_INVALID_STOPS)
   {
      Log("Broker rejected SL/TP as invalid stops; retrying without stops.");
      if(dir > 0)
         sent = g_trade.Buy(volume, _Symbol, 0.0, 0.0, 0.0, InpTradeComment);
      else
         sent = g_trade.Sell(volume, _Symbol, 0.0, 0.0, 0.0, InpTradeComment);

      retcode = g_trade.ResultRetcode();
      done = (sent && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL));

      if(done)
      {
         openedTicket = ResolveOpenedTicket();
         if(openedTicket <= 0)
         {
            if(PositionCountForLimits() > 0)
            {
               g_hardBlocked = true;
               Print("CRITICAL: stop-less entry succeeded but its ticket could not be resolved. Flattening EA positions and blocking the EA.");
               CloseAllPositions("unresolved unprotected entry");
               if(PositionCount() > 0)
                  Print("CRITICAL: an EA position may still be open without a stop. The guard loop will retry; verify manually.");
            }
            else
               Log("Stop-less order reported done but no matching position exists; nothing to protect.");
            g_tradesToday++;
            return false;
         }

         bool attached = g_trade.PositionModify(openedTicket, sl, tp);
         if(!attached)
         {
            PrintFormat("SL/TP attach failed for %I64u (%u %s); retrying SL only.",
                        openedTicket,
                        g_trade.ResultRetcode(),
                        g_trade.ResultRetcodeDescription());
            attached = g_trade.PositionModify(openedTicket, sl, 0.0);
         }

         if(!attached)
         {
            PrintFormat("Failed to attach SL to position %I64u: %u %s. Closing it instead.",
                        openedTicket,
                        g_trade.ResultRetcode(),
                        g_trade.ResultRetcodeDescription());

            if(g_trade.PositionClose(openedTicket))
            {
               Print("Unprotected position closed immediately for safety.");
            }
            else
            {
               g_unprotectedTicket = openedTicket;
               PrintFormat("CRITICAL: could not close unprotected position %I64u. Emergency close will retry.",
                           openedTicket);
            }
            g_tradesToday++;
            return false;
         }
      }
   }

   if(!done)
   {
      PrintFormat("Order failed. retcode=%u (%s) vol=%.2f sl=%s tp=%s",
                  retcode,
                  g_trade.ResultRetcodeDescription(),
                  volume,
                  DoubleToString(sl, _Digits),
                  DoubleToString(tp, _Digits));
      return false;
   }

   g_tradesToday++;
   ulong ticket = openedTicket;
   if(ticket <= 0)
      ticket = FindNewestPositionTicket();

   if(ticket > 0)
   {
      AddState(ticket, slDistance);
      if(!MQLInfoInteger(MQL_TESTER))
      {
         GlobalVariableSet(RiskKey(ticket), slDistance);
         GlobalVariableSet(PartialKey(ticket), 0.0);
      }
      PrintFormat("OPEN %s %.2f lots | ref=%s SL=%s TP=%s | riskDist=%s | tradesToday=%d",
                  (dir > 0 ? "BUY" : "SELL"),
                  volume,
                  DoubleToString(entryPrice, _Digits),
                  DoubleToString(sl, _Digits),
                  DoubleToString(tp, _Digits),
                  DoubleToString(slDistance, _Digits),
                  g_tradesToday);
   }
   else
      Log("Order reported done but its position ticket was not resolved; tracking state will be rebuilt.");
   return true;
}

//+------------------------------------------------------------------+
//| Trade management                                                 |
//+------------------------------------------------------------------+
bool IsStopDistanceOK(const long type, const double stop)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   double minDistance = StopsLevelPrice() + _Point * 2.0;
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   if(freeze > 0.0)
   {
      if(type == POSITION_TYPE_BUY && MathAbs(bid - stop) < freeze)
         return false;
      if(type == POSITION_TYPE_SELL && MathAbs(stop - ask) < freeze)
         return false;
   }

   if(type == POSITION_TYPE_BUY)
      return (bid - stop) >= minDistance;
   return (stop - ask) >= minDistance;
}

void ManagePositions()
{
   // Use the last closed M15 ATR so trailing does not tighten on a
   // still-forming bar.
   double atr = 0.0;
   if(!GetBufferValue(g_hAtrSignal, 0, 1, atr) || atr <= 0.0)
   {
      if(!GetBufferValue(g_hAtrSignal, 0, 2, atr))
         return;
   }
   if(atr <= 0.0)
      return;

   int biasNow = (InpExitOnBiasFlip ? GetBias() : 0);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      long   type   = PositionGetInteger(POSITION_TYPE);
      double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);
      double tp     = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || volume <= 0.0 || bid <= 0.0 || ask <= 0.0)
         continue;

      // Recovery path: a position with this EA's magic should always have
      // an initial stop. If it is missing (e.g. terminal restart after a
      // failed stop attachment), try to restore one.
      if(sl <= 0.0)
      {
         double spreadNow = ask - bid;
         double minDist = StopsLevelPrice() + spreadNow + _Point * 3.0;
         double nominalDist = InpSlAtrMult * atr;
         double adverse = (type == POSITION_TYPE_BUY ? entry - bid : ask - entry);
         bool mustClose = (adverse >= nominalDist);

         // Clamp the recovery stop to the broker minimum, and anchor it to
         // the current market so it is always a valid stop distance away.
         double recoveryDist = MathMax(nominalDist, minDist);
         double recoverySL = (type == POSITION_TYPE_BUY
                              ? bid - recoveryDist
                              : ask + recoveryDist);
         recoverySL = RoundPrice(recoverySL);

         bool recovered = false;
         if(IsStopDistanceOK(type, recoverySL))
         {
            recovered = g_trade.PositionModify(ticket, recoverySL, tp);
            if(!recovered)
               recovered = g_trade.PositionModify(ticket, recoverySL, 0.0);
         }

         if(recovered)
         {
            sl = recoverySL;
            PrintFormat("Attached missing initial SL to position %I64u at %s.",
                        ticket,
                        DoubleToString(recoverySL, _Digits));
         }
         else
         {
            Log(StringFormat("WARNING: position %I64u has no SL and recovery SL could not be attached.",
                             ticket));
            // Track it so TryCloseUnprotected() flattens it instead of
            // leaving a permanently unprotected position.
            g_unprotectedTicket = ticket;
         }

         if(mustClose)
         {
            if(g_trade.PositionClose(ticket))
            {
               Log("Closed a stop-less position whose loss exceeded the nominal risk.");
               continue;
            }
            if(!recovered)
               g_unprotectedTicket = ticket;
         }

         if(!recovered)
            continue;
      }

      if(InpExitOnBiasFlip &&
         ((type == POSITION_TYPE_BUY && biasNow < 0) ||
          (type == POSITION_TYPE_SELL && biasNow > 0)))
      {
         if(g_trade.PositionClose(ticket))
            Log("Closed position on H4 bias flip.");
         continue;
      }

      int stateIndex = FindState(ticket);
      if(stateIndex < 0)
      {
         double risk = atr * InpSlAtrMult;
         bool skipPartial = InpUsePartialClose;

         // Restore the exact initial risk and partial-close state when the
         // terminal was restarted. If the keys are missing (position opened
         // by an older build), keep the conservative ATR fallback and skip
         // the partial exit to avoid a double partial close.
         if(!MQLInfoInteger(MQL_TESTER))
         {
            string rk = RiskKey(ticket);
            if(GlobalVariableCheck(rk))
            {
               double storedRisk = GlobalVariableGet(rk);
               if(storedRisk > 0.0)
                  risk = storedRisk;
            }

            string pk = PartialKey(ticket);
            if(GlobalVariableCheck(pk))
               skipPartial = (GlobalVariableGet(pk) > 0.5);
         }
         else
            skipPartial = false;

         if(risk <= 0.0 && sl > 0.0)
            risk = MathAbs(entry - sl);
         AddState(ticket, risk);
         stateIndex = FindState(ticket);
         if(stateIndex < 0)
            continue;

         g_states[stateIndex].partialDone = skipPartial;
      }

      double risk = g_states[stateIndex].initialRisk;
      if(risk <= 0.0)
         risk = atr * InpSlAtrMult;
      if(risk <= 0.0)
         continue;

      double profitDistance = (type == POSITION_TYPE_BUY ? (bid - entry) : (entry - ask));

      // CTrade::PositionClosePartial is documented for hedging accounts.
      // On netting/exchange accounts the aggregate position is managed as
      // one unit, so partial closing is intentionally skipped.
      if(InpUsePartialClose && IsHedgingAccount() && !g_states[stateIndex].partialDone &&
         profitDistance >= InpPartialAtR * risk)
      {
         double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double closeVolume = NormalizeVolume(volume * InpPartialPercent / 100.0);
         if(closeVolume >= minVolume && (volume - closeVolume) >= minVolume - 1e-9)
         {
            bool partialSent = g_trade.PositionClosePartial(ticket, closeVolume);
            uint partialRc = g_trade.ResultRetcode();
            if(partialSent &&
               (partialRc == TRADE_RETCODE_DONE || partialRc == TRADE_RETCODE_DONE_PARTIAL))
            {
               g_states[stateIndex].partialDone = true;
               if(!MQLInfoInteger(MQL_TESTER))
                  GlobalVariableSet(PartialKey(ticket), 1.0);
               PrintFormat("Partial close %.2f lots on ticket %I64u", closeVolume, ticket);
            }
         }
      }

      double desiredSL = sl;
      bool changed = false;
      double spread = ask - bid;
      double buffer = MathMax(StopsLevelPrice(), spread) + InpBreakevenOffsetPts * _Point;

      if(InpUseBreakeven && profitDistance >= InpBreakevenAtR * risk)
      {
         double be = (type == POSITION_TYPE_BUY ? entry + buffer : entry - buffer);
         if(type == POSITION_TYPE_BUY && be > desiredSL)
         {
            desiredSL = be;
            changed = true;
         }
         else if(type == POSITION_TYPE_SELL && (desiredSL == 0.0 || be < desiredSL))
         {
            desiredSL = be;
            changed = true;
         }
      }

      if(InpUseTrailing && profitDistance >= InpTrailStartR * risk)
      {
         double trail = (type == POSITION_TYPE_BUY
                         ? bid - InpTrailAtrMult * atr
                         : ask + InpTrailAtrMult * atr);
         if(type == POSITION_TYPE_BUY && trail > desiredSL)
         {
            desiredSL = trail;
            changed = true;
         }
         else if(type == POSITION_TYPE_SELL && (desiredSL == 0.0 || trail < desiredSL))
         {
            desiredSL = trail;
            changed = true;
         }
      }

      if(changed)
      {
         desiredSL = RoundPrice(desiredSL);
         bool improves = false;
         if(type == POSITION_TYPE_BUY)
            improves = (sl <= 0.0 || desiredSL > sl + _Point * 0.5);
         else
            improves = (sl <= 0.0 || desiredSL < sl - _Point * 0.5);

         if(improves && IsStopDistanceOK(type, desiredSL))
         {
            if(!g_trade.PositionModify(ticket, desiredSL, tp))
               Log(StringFormat("SL modify failed for %I64u: %u %s",
                                ticket,
                                g_trade.ResultRetcode(),
                                g_trade.ResultRetcodeDescription()));
         }
      }
   }
   PruneStates();
}

//+------------------------------------------------------------------+
//| Entry flow                                                       |
//+------------------------------------------------------------------+
void TryEntries(const datetime now)
{
   if(g_cooldownUntil > 0 && now < g_cooldownUntil)
      return;
   if(!SpreadOK())
      return;
   if(!DataReady())
      return;

   int bias = GetBias();
   if(bias == 0)
      return;
   if(!SymbolAllowsDirection(bias))
      return;

   double adx = 0.0;
   double diPlus = 0.0;
   double diMinus = 0.0;
   if(!GetAdx(adx, diPlus, diMinus))
      return;
   if(adx < InpAdxMin)
      return;
   if(bias > 0 && diPlus <= diMinus)
      return;
   if(bias < 0 && diMinus <= diPlus)
      return;

   double atr = 0.0;
   if(!GetBufferValue(g_hAtrSignal, 0, 1, atr))
      return;
   double close1 = iClose(_Symbol, InpSignalTF, 1);
   if(atr <= 0.0 || close1 <= 0.0)
      return;

   double atrPercent = atr / close1 * 100.0;
   if(atrPercent < InpMinAtrPercent || atrPercent > InpMaxAtrPercent)
      return;

   int signal = GetSignal(bias, adx, atr);
   if(signal != 0)
   {
      if(!OpenTrade(signal, atr))
         Log("Entry signal found but order was not opened.");
   }
}

//+------------------------------------------------------------------+
//| Hard guards                                                      |
//+------------------------------------------------------------------+
bool DailyGuard()
{
   if(g_dayBlocked)
   {
      if(InpCloseOnDailyBreach)
         RetryGuardClose("daily guard retry");
      return true;
   }
   if(InpMaxDailyLossPct <= 0.0 && InpDailyProfitTargetPct <= 0.0)
      return false;
   if(g_dayStartEquity <= 0.0)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double pct = (equity - g_dayStartEquity) / g_dayStartEquity * 100.0;

   if(InpMaxDailyLossPct > 0.0 && pct <= -InpMaxDailyLossPct)
   {
      g_dayBlocked = true;
      PersistDayBlock();
      PrintFormat("DAILY LOSS GUARD: %.2f%% (limit %.2f%%). New trades blocked until next server day.",
                  pct, InpMaxDailyLossPct);
      if(InpCloseOnDailyBreach)
         CloseAllPositions("daily loss guard");
      return true;
   }

   if(InpDailyProfitTargetPct > 0.0 && pct >= InpDailyProfitTargetPct)
   {
      g_dayBlocked = true;
      PersistDayBlock();
      PrintFormat("DAILY TARGET REACHED: +%.2f%% (target %.2f%%). Trading stopped for today.",
                  pct, InpDailyProfitTargetPct);
      if(InpCloseOnDailyBreach)
         CloseAllPositions("daily profit target");
      return true;
   }
   return false;
}

bool TotalGuard()
{
   // g_hardBlocked can also be set by the unresolved stop-less entry path,
   // so the flatten retry must run even when the total-DD guard is disabled.
   if(g_hardBlocked)
   {
      RetryGuardClose("hard-block retry");
      return true;
   }
   if(!InpUseTotalDDGuard || InpMaxTotalDDPct <= 0.0)
      return false;
   if(g_peakEquity <= 0.0)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = (g_peakEquity - equity) / g_peakEquity * 100.0;
   if(drawdown >= InpMaxTotalDDPct)
   {
      g_hardBlocked = true;
      PrintFormat("TOTAL DD GUARD: equity %s is %.2f%% below peak %s (limit %.2f%%). EA blocked until reload/reset.",
                  DoubleToString(equity, 2),
                  drawdown,
                  DoubleToString(g_peakEquity, 2),
                  InpMaxTotalDDPct);
      CloseAllPositions("total drawdown guard");
      SavePeakEquity();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Chart panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel)
      return;
   ulong nowMs = GetTickCount64();
   if(nowMs - g_lastPanelMs < 1000)
      return;
   g_lastPanelMs = nowMs;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dayPct = 0.0;
   if(g_dayStartEquity > 0.0)
      dayPct = (equity - g_dayStartEquity) / g_dayStartEquity * 100.0;

   double atr = 0.0;
   double adx = 0.0;
   double diPlus = 0.0;
   double diMinus = 0.0;
   double rsi = 0.0;
   GetBufferValue(g_hAtrSignal, 0, 1, atr);
   GetAdx(adx, diPlus, diMinus);
   GetBufferValue(g_hRsiSignal, 0, 1, rsi);

   int bias = GetBias();
   string biasText = (bias > 0 ? "BULL" : (bias < 0 ? "BEAR" : "FLAT"));

   string status = "ACTIVE";
   if(!InpEnableTrading)
      status = "DISABLED";
   else if(g_hardBlocked)
      status = "HARD BLOCK";
   else if(g_dayBlocked)
      status = "DAY BLOCK";
   else if(g_unprotectedTicket > 0)
      status = "UNPROTECTED POSITION";
   else if(!MQLInfoInteger(MQL_TESTER) &&
           (TerminalInfoInteger(TERMINAL_CONNECTED) == 0 ||
            TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0 ||
            MQLInfoInteger(MQL_TRADE_ALLOWED) == 0 ||
            AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0 ||
            AccountInfoInteger(ACCOUNT_TRADE_EXPERT) == 0))
      status = "TERMINAL BLOCK";
   else if(InpUseSessionFilter && !InSession(TimeCurrent()))
      status = "OUT OF SESSION";
   else if(ManualBlackout(TimeCurrent()))
      status = "NEWS WINDOW";
   else if(g_cooldownUntil > TimeCurrent())
      status = "COOLDOWN";
   else if(!SpreadOK())
      status = "SPREAD FILTER";
   else if(PositionCountForLimits() >= EffectiveMaxPositions())
      status = "IN POSITION";

   double close1 = iClose(_Symbol, InpSignalTF, 1);
   double atrPct = (close1 > 0.0 ? atr / close1 * 100.0 : 0.0);

   string text = "XAUUSD Adaptive EA  |  " + _Symbol + "\n";
   text += "Status: " + status + "   Bias(H4): " + biasText + "   ADX(H1): " + DoubleToString(adx, 1) + "\n";
   text += "Equity: " + DoubleToString(equity, 2) +
           "   Day P&L: " + DoubleToString(dayPct, 2) + "%" +
           "   Entries: " + IntegerToString(g_tradesToday) + "/" + IntegerToString(InpMaxTradesPerDay) + "\n";
   text += "Spread: " + DoubleToString(SpreadUsd(), _Digits) + " USD" +
           "   ATR(M15): " + DoubleToString(atr, _Digits) +
           " (" + DoubleToString(atrPct, 2) + "%)" +
           "   RSI: " + DoubleToString(rsi, 1) + "\n";
   text += "Positions: " + IntegerToString(PositionCountForLimits()) + "/" + IntegerToString(EffectiveMaxPositions()) +
           "   Peak equity: " + DoubleToString(g_peakEquity, 2);
   if(g_cooldownUntil > TimeCurrent())
      text += "\nCooldown until: " + TimeToString(g_cooldownUntil, TIME_DATE | TIME_MINUTES);
   Comment(text);
}

//+------------------------------------------------------------------+
//| Input validation                                                 |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(InpMagic <= 0)
   {
      Print("Magic number must be a positive integer (avoid managing manual trades).");
      return false;
   }
   if(StringLen(InpTradeComment) > 31)
   {
      Print("Trade comment must be 31 characters or fewer.");
      return false;
   }
   if(InpEntryMode < XAU_ENTRY_AUTO || InpEntryMode > XAU_ENTRY_BOTH)
   {
      Print("Invalid entry mode.");
      return false;
   }
   if(InpBiasTF == PERIOD_CURRENT || InpFilterTF == PERIOD_CURRENT || InpSignalTF == PERIOD_CURRENT)
   {
      Print("Use explicit timeframes (not PERIOD_CURRENT).");
      return false;
   }
   if(PeriodSeconds(InpSignalTF) >= PeriodSeconds(InpFilterTF) ||
      PeriodSeconds(InpFilterTF) >= PeriodSeconds(InpBiasTF))
   {
      Print("Timeframes must satisfy signal < filter < bias (e.g. M15 < H1 < H4).");
      return false;
   }
   if(InpEmaFastBias >= InpEmaSlowBias || InpEmaFastBias < 5 || InpEmaSlowBias < 20)
   {
      Print("Bias EMAs invalid: fast must be < slow and both sensible.");
      return false;
   }
   if(InpEmaPullback >= InpEmaTrend || InpEmaPullback < 5 || InpEmaTrend < 10)
   {
      Print("Signal EMAs invalid: pullback EMA must be < trend EMA and both sensible.");
      return false;
   }
   if(InpAdxPeriod < 5 || InpRsiPeriod < 5 || InpAtrPeriod < 5)
   {
      Print("Indicator periods must be >= 5.");
      return false;
   }
   if(InpSlippagePoints < 0 || InpSlippagePoints > 10000)
   {
      Print("Slippage must be 0..10000 points.");
      return false;
   }
   if(InpAdxMin < 0.0 || InpAdxStrong <= InpAdxMin)
   {
      Print("ADX thresholds invalid: strong must be > min.");
      return false;
   }
   if(InpBreakoutLookback < 5)
   {
      Print("Breakout lookback must be >= 5.");
      return false;
   }
   if(InpMinAtrPercent < 0.0 || InpMaxAtrPercent <= InpMinAtrPercent)
   {
      Print("ATR percentage bounds invalid.");
      return false;
   }
   if(InpPullbackTolAtr < 0.0 || InpBreakoutBufferAtr < 0.0 || InpMinBodyAtr < 0.0)
   {
      Print("Pullback tolerance, breakout buffer and minimum body cannot be negative.");
      return false;
   }
   if(InpBreakevenOffsetPts < 0 || InpBreakevenOffsetPts > 100000)
   {
      Print("Break-even offset must be between 0 and 100000 points.");
      return false;
   }
   if(InpSlAtrMult <= 0.0 || InpTpAtrMult <= 0.0)
   {
      Print("SL/TP ATR multipliers must be > 0.");
      return false;
   }
   if(InpRiskMode == XAU_RISK_PERCENT &&
      (InpRiskPercent <= 0.0 || InpRiskPercent > 5.0))
   {
      Print("Risk percent must be in (0, 5].");
      return false;
   }
   if(InpRiskMode == XAU_RISK_FIXED)
   {
      if(InpFixedLot <= 0.0)
      {
         Print("Fixed lot must be > 0.");
         return false;
      }
      double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(vmin > 0.0 && InpFixedLot < vmin - 1e-9)
      {
         PrintFormat("Fixed lot %.4f is below the broker minimum %.2f.", InpFixedLot, vmin);
         return false;
      }
   }
   if(InpCommissionPerLot < 0.0)
   {
      Print("Commission per lot cannot be negative.");
      return false;
   }
   if(InpMaxPositions < 1 || InpMaxPositions > 5)
   {
      Print("Max positions must be 1..5.");
      return false;
   }
   if(InpRiskMode == XAU_RISK_PERCENT && InpMaxDailyLossPct > 0.0 &&
      InpRiskPercent * (double)InpMaxPositions > InpMaxDailyLossPct + 1e-9)
   {
      PrintFormat("Aggregate risk %.2f%% (%d positions x %.2f%%) exceeds the daily loss limit %.2f%%.",
                  InpRiskPercent * InpMaxPositions,
                  InpMaxPositions,
                  InpRiskPercent,
                  InpMaxDailyLossPct);
      return false;
   }
   if(InpMaxTradesPerDay < 1 || InpMaxTradesPerDay > 20)
   {
      Print("Max trades per day must be 1..20.");
      return false;
   }
   if(InpMaxDailyLossPct < 0.0 || InpDailyProfitTargetPct < 0.0)
   {
      Print("Daily percentages cannot be negative.");
      return false;
   }
   if(InpMaxDailyLossPct > 100.0 || InpDailyProfitTargetPct > 100.0 || InpMaxTotalDDPct > 100.0)
   {
      Print("Percentage limits above 100% are not allowed.");
      return false;
   }
   if(InpUseTotalDDGuard && InpMaxTotalDDPct <= 0.0)
   {
      Print("Total DD guard enabled but limit is <= 0.");
      return false;
   }
   if(InpCloseOnDailyBreach && InpMaxDailyLossPct <= 0.0 && InpDailyProfitTargetPct <= 0.0)
   {
      Print("Close-on-breach is on but both daily limits are disabled. Set a limit or disable the option.");
      return false;
   }
   if(InpUseBreakeven && InpBreakevenAtR <= 0.0)
   {
      Print("Break-even trigger must be > 0.");
      return false;
   }
   if(InpUseTrailing && (InpTrailStartR <= 0.0 || InpTrailAtrMult <= 0.0))
   {
      Print("Trailing parameters must be > 0.");
      return false;
   }
   if(InpUsePartialClose &&
      (InpPartialPercent <= 0.0 || InpPartialPercent >= 100.0 || InpPartialAtR <= 0.0))
   {
      Print("Partial close requires 0 < percent < 100 and trigger > 0.");
      return false;
   }
   if(InpCooldownHoursAfterLoss < 0.0)
   {
      Print("Cooldown hours cannot be negative.");
      return false;
   }
   if(InpSession1StartHour < 0 || InpSession1StartHour > 23 ||
      InpSession1EndHour < 0 || InpSession1EndHour > 24 ||
      InpSession2StartHour < 0 || InpSession2StartHour > 23 ||
      InpSession2EndHour < 0 || InpSession2EndHour > 24)
   {
      Print("Session hours must be within 0..24.");
      return false;
   }
   if(InpUseSessionFilter &&
      InpSession1EndHour == InpSession1StartHour &&
      InpSession2EndHour == InpSession2StartHour)
   {
      Print("Session filter enabled but both windows are zero-length.");
      return false;
   }
   if(InpFridayCloseHour < 0 || InpFridayCloseHour > 23)
   {
      Print("Friday close hour must be 0..23 (0 disables).");
      return false;
   }
   if(InpMaxSpreadUsd < 0.0)
   {
      Print("Max spread cannot be negative.");
      return false;
   }
   if(InpNewsMinutesBefore < 0 || InpNewsMinutesAfter < 0 ||
      InpNewsMinutesBefore > 1440 || InpNewsMinutesAfter > 1440)
   {
      Print("News buffer minutes must be between 0 and 1440.");
      return false;
   }
   if(InpUseCalendarFilter && StringLen(InpCalendarCurrency) == 0)
   {
      Print("Calendar filter enabled but the currency is empty.");
      return false;
   }
   if(InpEmaSlowBias > 1000 || InpEmaTrend > 1000 || InpBreakoutLookback > 500)
   {
      Print("Unreasonably large periods; check inputs.");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Init / tick / deinit                                             |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
   if(g_hEmaFastBias != INVALID_HANDLE) { IndicatorRelease(g_hEmaFastBias); g_hEmaFastBias = INVALID_HANDLE; }
   if(g_hEmaSlowBias != INVALID_HANDLE) { IndicatorRelease(g_hEmaSlowBias); g_hEmaSlowBias = INVALID_HANDLE; }
   if(g_hAdxFilter   != INVALID_HANDLE) { IndicatorRelease(g_hAdxFilter);   g_hAdxFilter   = INVALID_HANDLE; }
   if(g_hEmaPullback != INVALID_HANDLE) { IndicatorRelease(g_hEmaPullback); g_hEmaPullback = INVALID_HANDLE; }
   if(g_hEmaTrend    != INVALID_HANDLE) { IndicatorRelease(g_hEmaTrend);    g_hEmaTrend    = INVALID_HANDLE; }
   if(g_hAtrSignal   != INVALID_HANDLE) { IndicatorRelease(g_hAtrSignal);   g_hAtrSignal   = INVALID_HANDLE; }
   if(g_hRsiSignal   != INVALID_HANDLE) { IndicatorRelease(g_hRsiSignal);   g_hRsiSignal   = INVALID_HANDLE; }
}

int OnInit()
{
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)InpSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   if(!IsHedgingAccount() && InpMaxPositions > 1)
      Print("Netting/exchange account detected: InpMaxPositions is effectively capped at 1 to avoid hidden position stacking.");

   g_hEmaFastBias = iMA(_Symbol, InpBiasTF, InpEmaFastBias, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlowBias = iMA(_Symbol, InpBiasTF, InpEmaSlowBias, 0, MODE_EMA, PRICE_CLOSE);
   g_hAdxFilter   = iADX(_Symbol, InpFilterTF, InpAdxPeriod);
   g_hEmaPullback = iMA(_Symbol, InpSignalTF, InpEmaPullback, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaTrend    = iMA(_Symbol, InpSignalTF, InpEmaTrend, 0, MODE_EMA, PRICE_CLOSE);
   g_hAtrSignal   = iATR(_Symbol, InpSignalTF, InpAtrPeriod);
   g_hRsiSignal   = iRSI(_Symbol, InpSignalTF, InpRsiPeriod, PRICE_CLOSE);

   if(g_hEmaFastBias == INVALID_HANDLE || g_hEmaSlowBias == INVALID_HANDLE ||
      g_hAdxFilter == INVALID_HANDLE || g_hEmaPullback == INVALID_HANDLE ||
      g_hEmaTrend == INVALID_HANDLE || g_hAtrSignal == INVALID_HANDLE ||
      g_hRsiSignal == INVALID_HANDLE)
   {
      Print("Failed to create one or more indicator handles.");
      ReleaseIndicators();
      return INIT_FAILED;
   }

   ParseBlackoutWindows();

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(InpResetPeakOnInit)
      {
         GlobalVariableSet(PeakKey(), g_peakEquity);
      }
      else
      {
         string key = PeakKey();
         if(GlobalVariableCheck(key))
            g_peakEquity = MathMax(g_peakEquity, GlobalVariableGet(key));
         else
            GlobalVariableSet(key, g_peakEquity);
      }
   }

   g_dayStart = 0;
   StartNewDay(TimeCurrent());

   if(!MQLInfoInteger(MQL_TESTER))
   {
      string cooldownKey = CooldownKey();
      if(GlobalVariableCheck(cooldownKey))
      {
         datetime until = (datetime)(long)GlobalVariableGet(cooldownKey);
         if(until > TimeCurrent())
         {
            g_cooldownUntil = until;
            Print("Restored loss cooldown until " + TimeToString(until, TIME_DATE | TIME_MINUTES));
         }
         else
            GlobalVariableDel(cooldownKey);
      }
   }

   CleanupTicketKeys();

   PrintFormat("Initialized on %s | digits=%d | point=%s | tickSize=%s | stopsLevel=%d pts",
               _Symbol,
               _Digits,
               DoubleToString(_Point, _Digits),
               DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Digits),
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
   PrintFormat("Risk mode=%s | risk=%.2f%% | SL=%.2fxATR | TP=%.2fxATR | maxTrades/day=%d",
               (InpRiskMode == XAU_RISK_PERCENT ? "percent" : "fixed"),
               (InpRiskMode == XAU_RISK_PERCENT ? InpRiskPercent : 0.0),
               InpSlAtrMult,
               InpTpAtrMult,
               InpMaxTradesPerDay);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Comment("");
   ReleaseIndicators();
   SavePeakEquity();
   Log(StringFormat("Deinitialized. reason=%d", reason));
}

bool IsNewBar(const ENUM_TIMEFRAMES timeframe)
{
   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, timeframe, 0);
   if(barTime <= 0)
      return false;
   if(lastBar == 0)
   {
      lastBar = barTime;
      return false;
   }
   if(barTime != lastBar)
   {
      lastBar = barTime;
      return true;
   }
   return false;
}

void OnTick()
{
   datetime now = TimeCurrent();
   StartNewDay(now);
   UpdatePeakEquity();
   TryCloseUnprotected();

   bool newSignalBar = IsNewBar(InpSignalTF);

   if(FridayCloseDue(now))
   {
      RetryGuardClose("Friday close window");
      UpdatePanel();
      return;
   }

   bool blocked = TotalGuard();
   if(!blocked)
      blocked = DailyGuard();

   // Manage existing positions even when new entries are blocked.
   ManagePositions();

   if(newSignalBar)
      SavePeakEquity();

   if(newSignalBar && !blocked && TradingAllowed() && IsEntryWindow(now))
   {
      if(g_tradesToday < InpMaxTradesPerDay && PositionCountForLimits() < EffectiveMaxPositions())
         TryEntries(now);
   }

   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Trade transaction events                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dealType == DEAL_TYPE_BALANCE || dealType == DEAL_TYPE_CREDIT)
   {
      double cash = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                    HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      AdjustForCashFlow(cash);
      return;
   }

   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
      return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   double pnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   if(pnl < 0.0 && InpCooldownHoursAfterLoss > 0.0)
   {
      g_cooldownUntil = (datetime)((long)TimeCurrent() +
                                  (long)(InpCooldownHoursAfterLoss * 3600.0));
      if(!MQLInfoInteger(MQL_TESTER))
         GlobalVariableSet(CooldownKey(), (double)(long)g_cooldownUntil);
      Log("Losing trade closed. Cooldown until " +
          TimeToString(g_cooldownUntil, TIME_DATE | TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Custom optimization criterion                                    |
//+------------------------------------------------------------------+
double OnTester()
{
   double profit = TesterStatistics(STAT_PROFIT);
   double equityDD = TesterStatistics(STAT_EQUITY_DD);
   double trades = TesterStatistics(STAT_TRADES);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);

   if(profit <= 0.0 || trades < 20.0 || equityDD <= 0.0)
      return 0.0;

   double score = (profit / equityDD) * MathSqrt(trades);
   if(profitFactor > 0.0)
      score *= MathMin(profitFactor, 3.0);
   return score;
}
//+------------------------------------------------------------------+
