#property link          "https://www.earnforex.com/metatrader-expert-advisors/atr-trailing-stop/"
#property version       "1.09"
#property strict
#property copyright     "EarnForex.com - 2019-2026"
#property description   "This expert advisor will trail the stop-loss using ATR as a distance from the price."
#property description   ""
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this EA cannot be held responsible for any damage or loss."
#property description   ""
#property description   "Find More on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_CONSIDER
{
    All = -1,       // ALL ORDERS
    Buy = OP_BUY,   // BUY ONLY
    Sell = OP_SELL, // SELL ONLY
};

enum ENUM_CUSTOMTIMEFRAMES
{
    CURRENT = PERIOD_CURRENT,           // CURRENT PERIOD
    M1 = PERIOD_M1,                     // M1
    M5 = PERIOD_M5,                     // M5
    M15 = PERIOD_M15,                   // M15
    M30 = PERIOD_M30,                   // M30
    H1 = PERIOD_H1,                     // H1
    H4 = PERIOD_H4,                     // H4
    D1 = PERIOD_D1,                     // D1
    W1 = PERIOD_W1,                     // W1
    MN1 = PERIOD_MN1,                   // MN1
};

input string Comment_1 = "====================";  // Expert Advisor Settings
input int ATRPeriod = 14;                         // ATR Period
input int Shift = 1;                              // Shift In The ATR Value (1=Previous Candle)
input double ATRMultiplier = 1.0;                 // ATR Multiplier
input double ActivationATRMult = 0;               // Activation threshold (in ATR multiples)
input int ActivationMinProfit = 0;                // Activation threshold (in points)
input string Comment_2 = "====================";  // Orders Filtering Options
input bool OnlyCurrentSymbol = true;              // Apply To Current Symbol Only
input ENUM_CONSIDER OnlyType = All;               // Apply To
input bool UseMagic = false;                      // Filter By Magic Number
input int MagicNumber = 0;                        // Magic Number (if above is true)
input bool UseComment = false;                    // Filter By Comment
input string CommentFilter = "";                  // Comment (if above is true)
input bool EnableTrailingParam = false;           // Enable Trailing Stop
input string Comment_3 = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = true;                        // Send Notification to Mobile
input bool SendEmail = true;                      // Send Notification via Email
input string Comment_3a = "===================="; // Graphical Window
input bool ShowPanel = true;                      // Show Graphical Panel
input string ExpertName = "MQLTA-ATRTS";          // Expert Name (to name the objects)
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel
input string Comment_4 = "====================";  // Potential Stop-Loss Lines
input bool ShowPotentialSLLines = false;          // Show Potential SL Lines
input color PotentialSLBuyColor = clrDodgerBlue;  // Potential Buy SL Line Color
input color PotentialSLSellColor = clrOrangeRed;  // Potential Sell SL Line Color
input ENUM_LINE_STYLE PotentialSLStyle = STYLE_DOT; // Potential SL Line Style
input int PotentialSLWidth = 1;                   // Potential SL Line Width
input string Comment_5 = "====================";  // Activation Lines
input bool ShowActivationLines = false;           // Show Activation Lines
input color ActivationBuyColor = clrDarkGray;     // Activation Buy Line Color
input color ActivationSellColor = clrDarkSlateGray; // Activation Sell Line Color
input ENUM_LINE_STYLE ActivationStyle = STYLE_DASH; // Activation Line Style
input int ActivationWidth = 1;                    // Activation Line Width
input int ActivationFontSize = 8;                 // Activation Label Font Size

int OrderOpRetry = 5;
bool EnableTrailing = EnableTrailingParam;
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

int OnInit()
{
    EnableTrailing = EnableTrailingParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(50 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (int)MathRound(150 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    if (ShowPanel) DrawPanel();

    DrawPotentialSLLines();
    DrawActivationLines();
    
    if (ShowPotentialSLLines || ShowActivationLines) EventSetTimer(1); // If lines are required, use timer to refresh the lines for off-market hours.

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    CleanPanel();
    CleanPotentialSLLines();
    CleanActivationLines();
}

void OnTick()
{
    if (EnableTrailing) TrailingStop();
    if (ShowPanel) DrawPanel();
    DrawPotentialSLLines();
    DrawActivationLines();
}

void OnTimer()
{
    DrawPotentialSLLines();
    DrawActivationLines();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == PanelEnableDisable)
        {
            ChangeTrailingEnabled();
        }
    }
    else if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27)
        {
            if (MessageBox("Are you sure you want to close the EA?", "EXIT ?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
    else if (id == CHARTEVENT_CHART_CHANGE)
    {
        RepositionActivationLabels();
    }
}

double GetStopLossBuy(string Instrument)
{
    double SLValue = SymbolInfoDouble(Instrument, SYMBOL_BID) - iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
    return SLValue;
}

double GetStopLossSell(string Instrument)
{
    double SLValue = SymbolInfoDouble(Instrument, SYMBOL_ASK) + iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift) * ATRMultiplier;
    return SLValue;
}

void TrailingStop()
{
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES ) == false)
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        if (OnlyCurrentSymbol && OrderSymbol() != Symbol()) continue;
        if (UseMagic && OrderMagicNumber() != MagicNumber) continue;
        if (UseComment && StringFind(OrderComment(), CommentFilter) < 0) continue;
        if (OnlyType != All && OrderType() != OnlyType) continue;

        double NewSL = 0;
        double NewTP = 0;
        string Instrument = OrderSymbol();

        if (ActivationATRMult > 0) // If there is ATR-based activated multiplier.
        {
            // Activation check: only start trailing after position in profit by ActivationATRMult * ATR
            double atr = iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift);
            double openPrice = OrderOpenPrice();
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(Instrument, SYMBOL_ASK);
            bool activated = true;
            if (OrderType() == OP_BUY)
            {
                activated = (currentBid - openPrice >= ActivationATRMult * atr);
            }
            else if (OrderType() == OP_SELL)
            {
                activated = (openPrice - currentAsk >= ActivationATRMult * atr);
            }
            if (!activated) continue; // Skip trailing until ATR-based threshold is reached.
        }
        if (ActivationMinProfit > 0) // If there is point-based activated multiplier.
        {
            // Activation check: only start trailing after position in profit by ActivationMinProfit points.
            double openPrice = OrderOpenPrice();
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(Instrument, SYMBOL_ASK);
            bool activated = true;
            if (OrderType() == OP_BUY)
            {
                activated = (currentBid - openPrice >= ActivationMinProfit * MarketInfo(Instrument, MODE_POINT));
            }
            else if (OrderType() == OP_SELL)
            {
                activated = (openPrice - currentAsk >= ActivationATRMult * MarketInfo(Instrument, MODE_POINT));
            }
            if (!activated) continue; // Skip trailing until ATR-based threshold is reached.
        }

        double SLBuy = GetStopLossBuy(Instrument);
        double SLSell = GetStopLossSell(Instrument);
        if ((SLBuy == 0) || (SLSell == 0))
        {
            Print("Not enough historical data - please load more candles for the selected timeframe.");
            return;
        }

        int eDigits = (int)MarketInfo(Instrument, MODE_DIGITS);
        SLBuy = NormalizeDouble(SLBuy, eDigits);
        SLSell = NormalizeDouble(SLSell, eDigits);
        double SLPrice = NormalizeDouble(OrderStopLoss(), eDigits);
        double TPPrice = NormalizeDouble(OrderTakeProfit(), eDigits);
        double Spread = MarketInfo(Instrument, MODE_SPREAD) * MarketInfo(Instrument, MODE_POINT);
        double StopLevel = MarketInfo(Instrument, MODE_STOPLEVEL) * MarketInfo(Instrument, MODE_POINT);
        // Adjust for tick size granularity.
        double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
        if (TickSize > 0)
        {
            SLBuy = NormalizeDouble(MathRound(SLBuy / TickSize) * TickSize, eDigits);
            SLSell = NormalizeDouble(MathRound(SLSell / TickSize) * TickSize, eDigits);
        }
        if ((OrderType() == OP_BUY) && (SLBuy < MarketInfo(Instrument, MODE_BID) - StopLevel))
        {
            NewSL = NormalizeDouble(SLBuy, eDigits);
            NewTP = TPPrice;
            if ((NewSL > SLPrice) || (SLPrice == 0))
            {
                ModifyOrder(OrderTicket(), OrderOpenPrice(), NewSL, NewTP);
            }
        }
        else if ((OrderType() == OP_SELL) && (SLSell > MarketInfo(Instrument, MODE_ASK) + StopLevel))
        {
            NewSL = NormalizeDouble(SLSell + Spread, eDigits);
            NewTP = TPPrice;
            if ((NewSL < SLPrice) || (SLPrice == 0))
            {
                ModifyOrder(OrderTicket(), OrderOpenPrice(), NewSL, NewTP);
            }
        }
    }
}

void ModifyOrder(int Ticket, double OpenPrice, double SLPrice, double TPPrice)
{
    if (OrderSelect(Ticket, SELECT_BY_TICKET) == false)
    {
        int Error = GetLastError();
        string ErrorText = GetLastErrorText(Error);
        Print("ERROR - SELECT TICKET - error selecting order ", Ticket, " return error: ", Error);
        return;
    }
    int eDigits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
    SLPrice = NormalizeDouble(SLPrice, eDigits);
    TPPrice = NormalizeDouble(TPPrice, eDigits);
    for (int i = 1; i <= OrderOpRetry; i++)
    {
        bool res = OrderModify(Ticket, OpenPrice, SLPrice, TPPrice, 0, clrBlue);
        if (res)
        {
            Print("TRADE - UPDATE SUCCESS - Order ", Ticket, " in ", OrderSymbol(), ": new stop-loss ", SLPrice, " new take-profit ", TPPrice);
            NotifyStopLossUpdate(Ticket, SLPrice, OrderSymbol());
            break;
        }
        else
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - UPDATE FAILED - error modifying order ", Ticket, " in ", OrderSymbol(), " return error: ", Error, " Open=", OpenPrice,
                  " Old SL=", OrderStopLoss(), " Old TP=", OrderTakeProfit(),
                  " New SL=", SLPrice, " New TP=", TPPrice, " Bid=", MarketInfo(OrderSymbol(), MODE_BID), " Ask=", MarketInfo(OrderSymbol(), MODE_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(int OrderNumber, double SLPrice, string symbol)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = ExpertName + " " + symbol + " Notification ";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + ExpertName + " Notification for " + symbol + "\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(OrderNumber) + " moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AlertText = ExpertName + " - " + symbol + " - stop-loss for order " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS));
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "stop-loss for order: " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)MarketInfo(symbol, MODE_DIGITS)) + "";
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}


string PanelBase = ExpertName + "-P-BAS";
string PanelLabel = ExpertName + "-P-LAB";
string PanelEnableDisable = ExpertName + "-P-ENADIS";
string PotentialSLBuyName = ExpertName + "-SL-BUY";
string PotentialSLSellName = ExpertName + "-SL-SELL";
string ActivationLinePrefix = ExpertName + "-ACT-";
string ActivationLabelPrefix = ExpertName + "-ACTL-";
void DrawPanel()
{
    string PanelText = "MQLTA ATRTS";
    string PanelToolTip = "ATR Trailing Stop-Loss By EarnForex.com";

    int Rows = 1;
    if (ObjectFind(0, PanelBase) < 0) ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    string EnableDisabledText = "";
    color EnableDisabledColor = clrNavy;
    color EnableDisabledBack = clrKhaki;
    if (EnableTrailing)
    {
        EnableDisabledText = "TRAILING ENABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkGreen;
    }
    else
    {
        EnableDisabledText = "TRAILING DISABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkRed;
    }

    DrawEdit(PanelEnableDisable,
             Xoff + 2,
             Yoff + (PanelMovY + 1)*Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Click to Enable or Disable the Trailing Stop Feature",
             ALIGN_CENTER,
             "Consolas",
             EnableDisabledText,
             false,
             EnableDisabledColor,
             EnableDisabledBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}

void CleanPanel()
{
    ObjectsDeleteAll(0, ExpertName + "-P-");
}

void DrawPotentialSLLines()
{
    if (!ShowPotentialSLLines)
    {
        CleanPotentialSLLines();
        return;
    }

    double atr = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod, Shift);
    if (atr == 0) return;

    double distance = ATRMultiplier * atr;
    double slBuyLevel = SymbolInfoDouble(Symbol(), SYMBOL_BID) - distance;
    double slSellLevel = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + distance;

    int eDigits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    slBuyLevel = NormalizeDouble(slBuyLevel, eDigits);
    slSellLevel = NormalizeDouble(slSellLevel, eDigits);

    CreateOrMoveHLine(PotentialSLBuyName, slBuyLevel, PotentialSLBuyColor, PotentialSLStyle, PotentialSLWidth,
                      "Potential Buy SL: " + DoubleToString(slBuyLevel, eDigits));
    CreateOrMoveHLine(PotentialSLSellName, slSellLevel, PotentialSLSellColor, PotentialSLStyle, PotentialSLWidth,
                      "Potential Sell SL: " + DoubleToString(slSellLevel, eDigits));
}

void CleanPotentialSLLines()
{
    ObjectDelete(0, PotentialSLBuyName);
    ObjectDelete(0, PotentialSLSellName);
}

void DrawActivationLines()
{
    if (!ShowActivationLines || !EnableTrailing)
    {
        CleanActivationLines();
        return;
    }

    // Activation lines only make sense when at least one activation threshold is set.
    if (ActivationATRMult == 0 && ActivationMinProfit == 0)
    {
        CleanActivationLines();
        return;
    }

    datetime leftTime = GetLeftVisibleBarTime();

    // Collect tickets of current symbol positions that should have activation lines.
    ulong activeTickets[];
    int activeCount = 0;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES ) == false)
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        int ticket = OrderTicket();
        if (OnlyCurrentSymbol && OrderSymbol() != Symbol()) continue;
        if (UseMagic && OrderMagicNumber() != MagicNumber) continue;
        if (UseComment && StringFind(OrderComment(), CommentFilter) < 0) continue;
        if (OnlyType != All && OrderType() != OnlyType) continue;

        string Instrument = OrderSymbol();
        double openPrice = OrderOpenPrice();
        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);

        // Calculate the activation distance — use whichever threshold is farther.
        double distATR = 0;
        double distPoints = 0;
        if (ActivationATRMult > 0) distATR = ActivationATRMult * iATR(Instrument, PERIOD_CURRENT, ATRPeriod, Shift);
        if (ActivationMinProfit > 0) distPoints = ActivationMinProfit * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        double activationDist = MathMax(distATR, distPoints);
        if (activationDist == 0) continue;

        double activationLevel = 0;
        color lineColor = clrNONE;
        string dirLabel = "";
        if (OrderType() == OP_BUY)
        {
            activationLevel = NormalizeDouble(openPrice + activationDist, eDigits);
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            if (SymbolInfoDouble(Instrument, SYMBOL_BID) >= activationLevel) continue; // Skip activation lines that have already been passed.
            lineColor = ActivationBuyColor;
            dirLabel = "Buy";
        }
        else if (OrderType() == OP_SELL)
        {
            activationLevel = NormalizeDouble(openPrice - activationDist, eDigits);
            double currentAsk = SymbolInfoDouble(Instrument, SYMBOL_ASK);
            if (SymbolInfoDouble(Instrument, SYMBOL_ASK) <= activationLevel) continue; // Skip activation lines that have already been passed.
            lineColor = ActivationSellColor;
            dirLabel = "Sell";
        }
        else continue;

        string lineName = ActivationLinePrefix + IntegerToString(ticket);
        string tooltip = "TSL Activation #" + IntegerToString(ticket) + " " + dirLabel + ": " + DoubleToString(activationLevel, eDigits);
        CreateOrMoveHLine(lineName, activationLevel, lineColor, ActivationStyle, ActivationWidth, tooltip);

        string labelName = ActivationLabelPrefix + IntegerToString(ticket);
        string labelText = "#" + IntegerToString(ticket) + " " + dirLabel + " TSL Activation";
        CreateOrMoveActivationLabel(labelName, leftTime, activationLevel, labelText, lineColor);

        ArrayResize(activeTickets, activeCount + 1);
        activeTickets[activeCount] = ticket;
        activeCount++;
    }

    // Remove activation lines and labels for positions that no longer exist.
    int totalObjects = ObjectsTotal(0, 0, OBJ_HLINE);
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_HLINE);
        if (StringFind(objName, ActivationLinePrefix) != 0) continue;
        // Extract ticket from the object name.
        string ticketStr = StringSubstr(objName, StringLen(ActivationLinePrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found)
        {
            ObjectDelete(0, objName);
            ObjectDelete(0, ActivationLabelPrefix + ticketStr);
        }
    }
    // Also clean orphaned labels (e.g. if the line was already removed).
    int totalText = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = totalText - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(objName, ActivationLabelPrefix) != 0) continue;
        string ticketStr = StringSubstr(objName, StringLen(ActivationLabelPrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found) ObjectDelete(0, objName);
    }
}

void CleanActivationLines()
{
    ObjectsDeleteAll(0, ActivationLinePrefix);
    ObjectsDeleteAll(0, ActivationLabelPrefix);
}

// Returns the time of the leftmost visible bar on the chart.
datetime GetLeftVisibleBarTime()
{
    int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    datetime barTime = 0;
    // iTime with shift = firstVisibleBar gives the leftmost visible bar's time.
    barTime = iTime(Symbol(), PERIOD_CURRENT, firstVisibleBar);
    if (barTime == 0) barTime = TimeCurrent(); // Fallback.
    return barTime;
}

void CreateOrMoveActivationLabel(string name, datetime time, double price, string text, color clr)
{
    ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, time);
    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, ActivationFontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// Repositions all activation labels to the current leftmost visible bar.
void RepositionActivationLabels()
{
    if ((!ShowActivationLines) || (!EnableTrailing)) return;
    if ((ActivationATRMult == 0) && (ActivationMinProfit == 0)) return;

    datetime leftTime = GetLeftVisibleBarTime();
    int totalText = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = totalText - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(objName, ActivationLabelPrefix) != 0) continue;
        ObjectSetInteger(0, objName, OBJPROP_TIME, leftTime);
    }
    ChartRedraw();
}

void CreateOrMoveHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width, string tooltip)
{
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            MessageBox("Automated trading is disabled in the platform's options! Please enable it via Tools->Options->Expert Advisors.", "WARNING", MB_OK);
            return;
        }
        if (!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            MessageBox("Live Trading is disabled in the expert advisor's settings! Please tick the Allow Live Trading checkbox on the Common tab.", "WARNING", MB_OK);
            return;
        }
        EnableTrailing = true;
    }
    else EnableTrailing = false;
    DrawPanel();
    DrawActivationLines();
    ChartRedraw();
}
//+------------------------------------------------------------------+