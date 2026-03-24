#property link          "https://www.earnforex.com/metatrader-expert-advisors/atr-trailing-stop/"
#property version       "1.09"

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
#include <Trade/Trade.mqh>

enum ENUM_CONSIDER
{
    All = -1,                  // ALL ORDERS
    Buy = POSITION_TYPE_BUY,   // BUY ONLY
    Sell = POSITION_TYPE_SELL, // SELL ONLY
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

string Symbols[]; // Will store symbols for handles.
int SymbolHandles[]; // Will store actual handles.

CTrade *Trade; // Trading object.

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

    ArrayResize(Symbols, 1, 10); // At least one (current symbol) and up to 10 reserved space.
    ArrayResize(SymbolHandles, 1, 10);
    
    Symbols[0] = Symbol();
    SymbolHandles[0] = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod);
    
	Trade = new CTrade;
	
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
    delete Trade;
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
            if (MessageBox("Are you sure you want to close the EA?", "EXIT?", MB_YESNO) == IDYES)
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

double GetATR(string symbol)
{
    double buf[1];
    int index = FindHandle(symbol);
    if (index == -1) // Not found.
    {
        // Create handle.
        int new_size = ArraySize(Symbols) + 1;
        ArrayResize(Symbols, new_size, 10);
        ArrayResize(SymbolHandles, new_size, 10);
        
        index = new_size - 1;
        Symbols[index] = symbol;
        SymbolHandles[index] = iATR(symbol, PERIOD_CURRENT, ATRPeriod);
    }
    // Copy buffer.
    int n = CopyBuffer(SymbolHandles[index], 0, Shift, 1, buf);
    if (n < 1)
    {
        Print("PSAR data not ready for " + Symbols[index] + ".");
    }
    return buf[0];
}

double GetStopLossBuy(string symbol)
{
    return (SymbolInfoDouble(symbol, SYMBOL_BID) - GetATR(symbol) * ATRMultiplier);
}

double GetStopLossSell(string symbol)
{
    return (SymbolInfoDouble(symbol, SYMBOL_ASK) + GetATR(symbol) * ATRMultiplier);
}

void TrailingStop()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            Print("PositionGetTicket failed " + IntegerToString(GetLastError()) + ".");
            continue;
        }

        if (PositionSelectByTicket(ticket) == false)
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - Unable to select the position #", IntegerToString(ticket), " - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        if ((OnlyCurrentSymbol) && (PositionGetString(POSITION_SYMBOL) != Symbol())) continue;
        if ((UseMagic) && (PositionGetInteger(POSITION_MAGIC) != MagicNumber)) continue;
        if ((UseComment) && (StringFind(PositionGetString(POSITION_COMMENT), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (PositionGetInteger(POSITION_TYPE) != OnlyType)) continue;

        double NewSL = 0;
        double NewTP = 0;
        string Instrument = PositionGetString(POSITION_SYMBOL);

        if (ActivationATRMult > 0) // If there is ATR-based activated multiplier.
        {
            // Activation check: only start trailing after position in profit by ActivationATRMult * ATR.
            double atr = GetATR(Instrument);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(Instrument, SYMBOL_ASK);
            bool activated = true;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                activated = (currentBid - openPrice >= ActivationATRMult * atr);
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                activated = (openPrice - currentAsk >= ActivationATRMult * atr);
            }
            if (!activated) continue; // Skip trailing until ATR-based threshold is reached.
        }
        if (ActivationMinProfit > 0) // If there is point-based activated multiplier.
        {
            // Activation check: only start trailing after position in profit by ActivationMinProfit points.
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(Instrument, SYMBOL_ASK);
            bool activated = true;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                activated = (currentBid - openPrice >= ActivationMinProfit * SymbolInfoDouble(Instrument, SYMBOL_POINT));
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                activated = (openPrice - currentAsk >= ActivationATRMult * SymbolInfoDouble(Instrument, SYMBOL_POINT));
            }
            if (!activated) continue; // Skip trailing until ATR-based threshold is reached.
        }
        
        double SLBuy = GetStopLossBuy(Instrument);
        double SLSell = GetStopLossSell(Instrument);
        if ((SLBuy == 0) || (SLSell == 0) || (SLSell == EMPTY_VALUE) || (SLSell == EMPTY_VALUE))
        {
            Print("Not enough historical data - please load more candles for the selected timeframe.");
            return;
        }

        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);
        SLBuy = NormalizeDouble(SLBuy, eDigits);
        SLSell = NormalizeDouble(SLSell, eDigits);
        double SLPrice = NormalizeDouble(PositionGetDouble(POSITION_SL), eDigits);
        double TPPrice = NormalizeDouble(PositionGetDouble(POSITION_TP), eDigits);
        double Spread = SymbolInfoInteger(Instrument, SYMBOL_SPREAD) * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        double StopLevel = SymbolInfoInteger(Instrument, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        // Adjust for tick size granularity.
        double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
        if (TickSize > 0)
        {
            SLBuy = NormalizeDouble(MathRound(SLBuy / TickSize) * TickSize, eDigits);
            SLSell = NormalizeDouble(MathRound(SLSell / TickSize) * TickSize, eDigits);
        }
        if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (SLBuy < SymbolInfoDouble(Instrument, SYMBOL_BID) - StopLevel))
        {
            NewSL = NormalizeDouble(SLBuy, eDigits);
            NewTP = TPPrice;
            if ((NewSL > SLPrice) || (SLPrice == 0))
            {
                
                ModifyOrder(ticket, NewSL, NewTP);
            }
        }
        else if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && (SLSell > SymbolInfoDouble(Instrument, SYMBOL_ASK) + StopLevel))
        {
            NewSL = NormalizeDouble(SLSell + Spread, eDigits);
            NewTP = TPPrice;
            if ((NewSL < SLPrice) || (SLPrice == 0))
            {
                ModifyOrder(ticket, NewSL, NewTP);
            }
        }
    }
}

void ModifyOrder(ulong Ticket, double SLPrice, double TPPrice)
{
    string symbol = PositionGetString(POSITION_SYMBOL);
    int eDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    SLPrice = NormalizeDouble(SLPrice, eDigits);
    TPPrice = NormalizeDouble(TPPrice, eDigits);
    for (int i = 1; i <= OrderOpRetry; i++)
    {
        bool res = Trade.PositionModify(Ticket, SLPrice, TPPrice);
        if (!res)
        {
            Print("Wrong position midification request: ", Ticket, " in ", symbol, " at SL = ", SLPrice, ", TP = ", TPPrice);
            return;
        }
		if ((Trade.ResultRetcode() == 10008) || (Trade.ResultRetcode() == 10009) || (Trade.ResultRetcode() == 10010)) // Success.
        {
            Print("TRADE - UPDATE SUCCESS - Position ", Ticket, " in ", symbol, ": new stop-loss ", SLPrice, " new take-profit ", TPPrice);
            NotifyStopLossUpdate(Ticket, SLPrice, symbol);
            break;
        }
        else
        {
			Print("Position Modify Return Code: ", Trade.ResultRetcodeDescription());
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - UPDATE FAILED - error modifying position ", Ticket, " in ", symbol, " return error: ", Error, " Open=", PositionGetDouble(POSITION_PRICE_OPEN),
                  " Old SL=", PositionGetDouble(POSITION_SL), " Old TP=", PositionGetDouble(POSITION_TP),
                  " New SL=", SLPrice, " New TP=", TPPrice, " Bid=", SymbolInfoDouble(symbol, SYMBOL_BID), " Ask=", SymbolInfoDouble(symbol, SYMBOL_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(ulong OrderNumber, double SLPrice, string symbol)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = ExpertName + " " + symbol + " Notification ";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + ExpertName + " Notification for " + symbol + "\r\n";
    EmailBody += "Stop-loss for position " + IntegerToString(OrderNumber) + " moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    string AlertText = symbol + " - stop-loss for position " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "stop-loss for position: " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "";
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
    string PanelToolTip = "ATR Trailing Stop-Loss by EarnForex.com";

    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
             Yoff + (PanelMovY + 1) * Rows + 2,
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

    double atr = GetATR(Symbol());
    if ((atr == 0) || (atr == EMPTY_VALUE)) return;

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

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if ((UseMagic) && (PositionGetInteger(POSITION_MAGIC) != MagicNumber)) continue;
        if ((UseComment) && (StringFind(PositionGetString(POSITION_COMMENT), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (PositionGetInteger(POSITION_TYPE) != OnlyType)) continue;

        string Instrument = PositionGetString(POSITION_SYMBOL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);

        // Calculate the activation distance — use whichever threshold is farther.
        double distATR = 0;
        double distPoints = 0;
        if (ActivationATRMult > 0) distATR = ActivationATRMult * GetATR(Instrument);
        if (ActivationMinProfit > 0) distPoints = ActivationMinProfit * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        double activationDist = MathMax(distATR, distPoints);
        if (activationDist == 0) continue;

        double activationLevel = 0;
        color lineColor = clrNONE;
        string dirLabel = "";
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            activationLevel = NormalizeDouble(openPrice + activationDist, eDigits);
            double currentBid = SymbolInfoDouble(Instrument, SYMBOL_BID);
            if (SymbolInfoDouble(Instrument, SYMBOL_BID) >= activationLevel) continue; // Skip activation lines that have already been passed.
            lineColor = ActivationBuyColor;
            dirLabel = "Buy";
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
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
            MessageBox("Algorithmic trading is disabled in the platform's options! Please enable it via Tools->Options->Expert Advisors.", "WARNING", MB_OK);
            return;
        }
        if (!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            MessageBox("Algo Trading is disabled in the advisor's settings! Please tick the Allow Algo Trading checkbox on the Common tab.", "WARNING", MB_OK);
            return;
        }
        EnableTrailing = true;
    }
    else EnableTrailing = false;
    DrawPanel();
    DrawActivationLines();
    ChartRedraw();
}

// Tries to find a handle for a symbol in arrays.
// Returns the index if found, -1 otherwise.
int FindHandle(string symbol)
{
    int size = ArraySize(Symbols);
    for (int i = 0; i < size; i++)
    {
        if (Symbols[i] == symbol) return i;
    }
    return -1;
}
//+------------------------------------------------------------------+