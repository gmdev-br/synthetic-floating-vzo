//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link "mladenfx@gmail.com"
#property copyright "© GM, 2020, 2021, 2022, 2023"
#property description "Synthetic Floating VZO"

#property indicator_separate_window
#property indicator_buffers 9
#property indicator_plots   8
#property indicator_label1  "Filling - VZO"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  C'55,55,55',C'55,55,55'
#property indicator_label2  "Volume zone oscillator"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  C'65,65,65',clrRed,clrLime
#property indicator_width2  3

#property indicator_label3  "REG"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  1

#property indicator_label4  "STDEV +1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMagenta
#property indicator_width4  1

#property indicator_label5  "STDEV -1"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_width5  1

#property indicator_label6  "STDEV +2"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrMagenta
#property indicator_width6  1

#property indicator_label7  "STDEV -2"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrMagenta
#property indicator_width7  1

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_REG_SOURCE {
   Open,           // Open
   High,           // High
   Low,             // Low
   Close,         // Close
   Typical,     // Typical
};

input  int                             inpPeriod         = 10;    // Period
input ENUM_REG_SOURCE                  inputSource = Close;
input ENUM_APPLIED_VOLUME              applied_volume    = VOLUME_TICK;          // Volume type
input  int                             inpFlLookBack     = 10;    // Floating levels look back period
input  double                          inpFlLevelUp      = 85;    // Floating levels up level %
input  double                          inpFlLevelDown    = 15;    // Floating levels down level %
input double                           InpExtremeOverbought       =  80.0; // Extreme overbought
input double                           InpHighOverbought       =  60.0; // High overbought
input double                           InpOverbought  =  40.0; // Overbought
input double                           InpOversold    =  -40.0; // Oversold
input double                           InpHighOversold       =  -60.0; // High oversold
input double                           InpExtremeOversold       =  -80.0; // Extreme oversold
input int                              inpSignalPeriod = 20;
input datetime                         DefaultInitialDate              = "2021.1.1 9:00:00";          // Data inicial padrão
input int                              WaitMilliseconds = 1500;  // Timer (milliseconds) for recalculation

input color                            ChannelCentralColor             = clrYellow;                      // Linha central: cor
input int                              ChannelCentralWidth             = 5;                              // Linha central: largura
input ENUM_LINE_STYLE                  ChannelCentralStyle             = STYLE_SOLID;                    // Linha central: estilo
input double                           ChannelWidth                    = 0.5;                            // CANAL DE REGRESSÃO: multiplicador do desvio
input double                           ChannelDeviationsOffset         = 0;                              // CANAL DE REGRESSÃO: deslocamento
input color                            RegChannelColor                 = clrMagenta;                     // CANAL DE REGRESSÃO: cor
input int                              RegChannelWidth                 = 1;                              // CANAL DE REGRESSÃO: largura
input ENUM_LINE_STYLE                  RegChannelStyle                 = STYLE_DOT;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double vzo[], vzoc[], levup[], levdn[], signal[];
long arrayVolume[];
double regChannelBuffer[];
double upChannel1[], upChannel2[];
double downChannel1[], downChannel2[];
double A, B, stdev;
datetime data_inicial;
int barFrom;
datetime arrayTime[];
double arrayOpen[], arrayHigh[], arrayLow[], arrayClose[];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   SetIndexBuffer(0, levup, INDICATOR_DATA);
   SetIndexBuffer(1, levdn, INDICATOR_DATA);
   SetIndexBuffer(2, vzo, INDICATOR_DATA);
   SetIndexBuffer(3, vzoc, INDICATOR_COLOR_INDEX);
//SetIndexBuffer(4, signal, INDICATOR_DATA);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   ArrayInitialize(regChannelBuffer, 0);
   ArrayInitialize(upChannel1, 0);
   ArrayInitialize(downChannel1, 0);
   ArrayInitialize(upChannel2, 0);
   ArrayInitialize(downChannel2, 0);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   SetIndexBuffer(4, regChannelBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, upChannel1, INDICATOR_DATA);
   SetIndexBuffer(6, downChannel1, INDICATOR_DATA);
   SetIndexBuffer(7, upChannel2, INDICATOR_DATA);
   SetIndexBuffer(8, downChannel2, INDICATOR_DATA);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   ArraySetAsSeries(regChannelBuffer, true);
   ArraySetAsSeries(upChannel1, true);
   ArraySetAsSeries(downChannel1, true);
   ArraySetAsSeries(upChannel2, true);
   ArraySetAsSeries(downChannel2, true);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   IndicatorSetInteger(INDICATOR_DIGITS, 1);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   for (int i = 0; i < 8; i++) {
      PlotIndexSetInteger(i, PLOT_SHOW_DATA, false);       //--- repeat for each plot
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   data_inicial = DefaultInitialDate;
   barFrom = iBarShift(NULL, PERIOD_CURRENT, data_inicial);
   _updateTimer = new MillisecondTimer(WaitMilliseconds, false);
   EventSetMillisecondTimer(WaitMilliseconds);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   ChartRedraw();
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   IndicatorSetString(INDICATOR_SHORTNAME, "SF VZO");
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   delete(_updateTimer);
   ChartRedraw();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double work[][2];
#define _vp 0
#define _tv 1
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Update() {
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   int totalRates = SeriesInfoInteger(NULL, PERIOD_CURRENT, SERIES_BARS_COUNT);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   int tempVar = CopyLow(NULL, PERIOD_CURRENT, 0, totalRates, arrayLow);
   tempVar = CopyClose(NULL, PERIOD_CURRENT, 0, totalRates, arrayClose);
   tempVar = CopyHigh(NULL, PERIOD_CURRENT, 0, totalRates, arrayHigh);
   tempVar = CopyOpen(NULL, PERIOD_CURRENT, 0, totalRates, arrayOpen);

   ArrayReverse(arrayLow);
   ArrayReverse(arrayClose);
   ArrayReverse(arrayHigh);
   ArrayReverse(arrayOpen);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   ArraySetAsSeries(arrayOpen, true);
   ArraySetAsSeries(arrayLow, true);
   ArraySetAsSeries(arrayClose, true);
   ArraySetAsSeries(arrayHigh, true);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   double tempVzo[];

   if (Bars(_Symbol, _Period) < totalRates)
      return false;

   if (ArrayRange(work, 0) != totalRates)
      ArrayResize(work, totalRates);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if (applied_volume == VOLUME_REAL)
      CopyRealVolume(NULL, PERIOD_CURRENT, 0, totalRates, arrayVolume);
   else
      CopyTickVolume(NULL, PERIOD_CURRENT, 0, totalRates, arrayVolume);

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   double alpha = 2.0 / (1.0 + inpPeriod);
   double arrayAlvo[];

   if (inputSource == High)
      ArrayCopy(arrayAlvo, arrayHigh);
   else if (inputSource == Low)
      ArrayCopy(arrayAlvo, arrayLow);
   else if (inputSource == Close)
      ArrayCopy(arrayAlvo, arrayClose);
   else if (inputSource == Open)
      ArrayCopy(arrayAlvo, arrayOpen);

   ArraySetAsSeries(arrayAlvo, true);

   for (int i = 0; i < totalRates; i++) {
      double sign = (i > 0) ? (arrayAlvo[i] > arrayAlvo[i - 1]) ? 1 : (arrayAlvo[i] < arrayAlvo[i - 1]) ? -1 : 0 : 0;
      double R = sign * arrayVolume[i];
      work[i][_vp] = (i == 0) ? R                      : work[i - 1][_vp] + alpha * (R             - work[i - 1][_vp]);
      work[i][_tv] = (i == 0) ? (double)arrayVolume[i] : work[i - 1][_tv] + alpha * (arrayVolume[i] - work[i - 1][_tv]);
      vzo[i] = (work[i][_tv] != 0) ? 100.0 * work[i][_vp] / work[i][_tv] : 0;
      //vzo[i] += 100;
      //signal[i]  = iEma(vzo[i], inpSignalPeriod, i, totalRates, 3);

      int _start = MathMax(i - inpFlLookBack, 0);
      double min = vzo[ArrayMinimum(vzo, _start, inpFlLookBack)];
      double max = vzo[ArrayMaximum(vzo, _start, inpFlLookBack)];
      double range = max - min;
      levup[i] = min + inpFlLevelUp * range / 100.0;
      levdn[i] = min + inpFlLevelDown * range / 100.0;
      //vzoc[i]  = (vzo[i] >= levup[i] && vzo[i] >= InpOverbought) ? 1 : (vzo[i] <= levdn[i] && vzo[i] <= InpOversold) ? 2 : 0;

   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   double dataArray[];
   ArrayCopy(dataArray, vzo);
   ArrayReverse(dataArray);
   barFrom = iBarShift(NULL, PERIOD_CURRENT, data_inicial);

   CalcAB(dataArray, 0, barFrom, A, B);
   stdev = GetStdDev(dataArray, 0, barFrom); //calculate standand deviation

   for(int n = 0; n < ArraySize(regChannelBuffer) - 1; n++) {
      regChannelBuffer[n] = 0.0;
      upChannel2[n] = 0.0;
      upChannel1[n] = 0.0;
      downChannel1[n] = 0.0;
      downChannel2[n] = 0.0;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   for (int i = 0; i < barFrom; i++) {
      upChannel2[i] = (A * (i) + B) + 2 * stdev;
      upChannel1[i] = (A * (i) + B) + 1.5 * stdev;
      regChannelBuffer[i] = (A * (i) + B);
      downChannel1[i] = (A * (i) + B) - 1.5 * stdev;
      downChannel2[i] = (A * (i) + B) - 2 * stdev;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   double temp1[], temp2[], temp3[], temp4[];
   ArrayCopy(temp1, upChannel2);
   ArrayCopy(temp2, upChannel1);
   ArrayCopy(temp3, downChannel1);
   ArrayCopy(temp4, downChannel2);

   for (int i = 0; i < totalRates  && !_StopFlag; i++) {
      //valc[i]  = (val[i] >= levup[i] && val[i] >= InpOverbought * multEscala && levup[i] >= InpExtremeOverbought * multEscala) ? 1 : (val[i] <= levdn[i] && val[i] <= InpOversold * multEscala && levdn[i] <= InpExtremeOversold * multEscala) ? 2 : 0;
      vzoc[i]  = (vzo[i] >= temp1[i] || (vzo[i] >= temp2[i] && vzo[i] >= 35)) ? 1 : ((vzo[i] <= temp4[i]) || (vzo[i] <= temp3[i] && vzo[i] <= -35)) ? 2 : 0;

   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[]) {
   return (1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double workEma[][4];
double iEma(double price, double period, int r, int _bars, int instanceNo = 0) {
   if(ArrayRange(workEma, 0) != _bars)
      ArrayResize(workEma, _bars);

   workEma[r][instanceNo] = price;
   if(r > 0 && period > 1)
      workEma[r][instanceNo] = workEma[r - 1][instanceNo] + (2.0 / (1.0 + period)) * (price - workEma[r - 1][instanceNo]);

   return(workEma[r][instanceNo]);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {

   if(id == CHARTEVENT_CHART_CHANGE) {
      _lastOK = false;
      CheckTimer();
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//Linear Regression Calculation for sample data: arr[]
//line equation  y = f(x)  = ax + b
void CalcAB(const double &arr[], int start, int end, double & a, double & b) {

   a = 0.0;
   b = 0.0;
   int size = MathAbs(start - end) + 1;
   if(size < 2)
      return;

   double sumxy = 0.0, sumx = 0.0, sumy = 0.0, sumx2 = 0.0;
   for(int i = start; i < end; i++) {
      sumxy += i * arr[i];
      sumy += arr[i];
      sumx += i;
      sumx2 += i * i;
   }

   double M = size * sumx2 - sumx * sumx;
   if(M == 0.0)
      return;

   a = (size * sumxy - sumx * sumy) / M;
   b = (sumy - a * sumx) / size;

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStdDev(const double & arr[], int start, int end) {
   int size = MathAbs(start - end) + 1;
   if(size < 2)
      return(0.0);

   double sum = 0.0;
   for(int i = start; i < end; i++) {
      sum = sum + arr[i];
   }

   sum = sum / size;

   double sum2 = 0.0;
   for(int i = start; i < end; i++) {
      sum2 = sum2 + (arr[i] - sum) * (arr[i] - sum);
   }

   sum2 = sum2 / (size - 1);
   sum2 = MathSqrt(sum2);

   return(sum2);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MillisecondTimer {

 private:
   int               _milliseconds;
 private:
   uint              _lastTick;

 public:
   void              MillisecondTimer(const int milliseconds, const bool reset = true) {
      _milliseconds = milliseconds;

      if(reset)
         Reset();
      else
         _lastTick = 0;
   }

 public:
   bool              Check() {
      uint now = getCurrentTick();
      bool stop = now >= _lastTick + _milliseconds;

      if(stop)
         _lastTick = now;

      return(stop);
   }

 public:
   void              Reset() {
      _lastTick = getCurrentTick();
   }

 private:
   uint              getCurrentTick() const {
      return(GetTickCount());
   }

};

bool _lastOK = false;
MillisecondTimer *_updateTimer;

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
   CheckTimer();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTimer() {
   EventKillTimer();

   if(_updateTimer.Check() || !_lastOK) {
      _lastOK = Update();
      //Print("aaaaa");

      EventSetMillisecondTimer(WaitMilliseconds);

      _updateTimer.Reset();
   } else {
      EventSetTimer(1);
   }
}

//+---------------------------------------------------------------------+
//| GetTimeFrame function - returns the textual timeframe               |
//+---------------------------------------------------------------------+
string GetTimeFrame(int lPeriod) {
   switch(lPeriod) {
   case PERIOD_M1:
      return("M1");
   case PERIOD_M2:
      return("M2");
   case PERIOD_M3:
      return("M3");
   case PERIOD_M4:
      return("M4");
   case PERIOD_M5:
      return("M5");
   case PERIOD_M6:
      return("M6");
   case PERIOD_M10:
      return("M10");
   case PERIOD_M12:
      return("M12");
   case PERIOD_M15:
      return("M15");
   case PERIOD_M20:
      return("M20");
   case PERIOD_M30:
      return("M30");
   case PERIOD_H1:
      return("H1");
   case PERIOD_H2:
      return("H2");
   case PERIOD_H3:
      return("H3");
   case PERIOD_H4:
      return("H4");
   case PERIOD_H6:
      return("H6");
   case PERIOD_H8:
      return("H8");
   case PERIOD_H12:
      return("H12");
   case PERIOD_D1:
      return("D1");
   case PERIOD_W1:
      return("W1");
   case PERIOD_MN1:
      return("MN1");
   }
   return IntegerToString(lPeriod);
}
//+------------------------------------------------------------------+
