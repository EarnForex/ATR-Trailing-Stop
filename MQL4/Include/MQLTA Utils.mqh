#property link          "https://www.earnforex.com/"
#property version       "1.00"
#property strict
#property copyright     "EarnForex.com - 2020"
#property description   ""
#property description   ""
#property description   ""
#property description   ""
#property description   "Find More on EarnForex.com"

//Check if the software is over the date of use, throw a message and return true if it is
bool UpdateCheckOver(string Name, datetime ExpiryDate, bool ShowAlert){
   if(TimeCurrent()>ExpiryDate){
      string EditText="Version Expired, This Product Must Be Updated";
      string AlertText="Version Expired, Please Download The New Version From MQL4TradingAutomation.com";
      DrawExpiry(Name,EditText); 
      if(ShowAlert){
         Alert(AlertText);
         Print(AlertText);    
      }
      return true;
   }
   else return false;
}

//Check if the software is over the warning date and throw a message if it is
void UpdateCheckWarning(string Name, datetime WarningDate, datetime ExpiryDate, bool ShowAlert){
   if(TimeCurrent()>WarningDate){
      string WarningDateStr=(string)TimeDay(ExpiryDate)+"/"+(string)TimeMonth(ExpiryDate)+"/"+(string)TimeYear(ExpiryDate);
      string EditText="This Product Version Will Stop Working On The "+WarningDateStr+"";
      string AlertText="This Product Version Will Stop Working On The "+WarningDateStr+", Please Download The New Version From MQL4TradingAutomation.com";
      DrawExpiry(Name,EditText); 
      if(ShowAlert){
         Alert(AlertText);
         Print(AlertText);    
      }
   }
}

//Draw a box to advise of the warning/expiry of the product
void DrawExpiry(string Name, string Text){
   string TextBoxName=Name+"ExpirationTextBox";
   if(ObjectFind(0,TextBoxName)<0){
      DrawEdit(TextBoxName,20,20,300,20,true,8,"",ALIGN_CENTER,"Arial",Text,true,clrNavy,clrKhaki,clrBlack);
   }
}

//Draw an edit box with the specified parameters
void DrawEdit( string Name, 
               int XStart,
               int YStart,
               int Width,
               int Height,
               bool ReadOnly,
               int EditFontSize,
               string Tooltip,
               int Align,
               string EditFont,
               string Text,
               bool Selectable, 
               color TextColor=clrBlack,
               color BGColor=clrWhiteSmoke,
               color BDColor=clrBlack
   ){

   if (ObjectFind(0, Name) < 0) ObjectCreate(0,Name,OBJ_EDIT,0,0,0);
   ObjectSet(Name,OBJPROP_XDISTANCE,XStart);
   ObjectSet(Name,OBJPROP_YDISTANCE,YStart);
   ObjectSetInteger(0,Name,OBJPROP_XSIZE,Width);
   ObjectSetInteger(0,Name,OBJPROP_YSIZE,Height);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,Name,OBJPROP_STATE,false);
   ObjectSetInteger(0,Name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,Name,OBJPROP_READONLY,ReadOnly);
   ObjectSetInteger(0,Name,OBJPROP_FONTSIZE,EditFontSize);
   ObjectSetString(0,Name,OBJPROP_TOOLTIP,Tooltip);
   ObjectSetInteger(0,Name,OBJPROP_ALIGN,Align);
   ObjectSetString(0,Name,OBJPROP_FONT,EditFont);
   ObjectSetString(0,Name,OBJPROP_TEXT,Text);
   ObjectSet(Name,OBJPROP_SELECTABLE,Selectable);
   ObjectSetInteger(0,Name,OBJPROP_COLOR,TextColor);
   ObjectSetInteger(0,Name,OBJPROP_BGCOLOR,BGColor);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_COLOR,BDColor);
   ObjectSetInteger(0,Name,OBJPROP_BACK,false);
}


//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
