#property copyright "VP: Volume Profile v6.0. © FXcoder"
#property link      "http://fxcoder.blogspot.com"
#property strict
#property indicator_chart_window
#property indicator_plots 0

#define PUT_IN_RANGE(A, L, H) ((H) < (L) ? (A) : ((A) < (L) ? (L) : ((A) > (H) ? (H) : (A))))
#define COLOR_IS_NONE(C) (((C) >> 24) != 0)
#define RGB_TO_COLOR(R, G, B) ((color)((((B) & 0x0000FF) << 16) + (((G) & 0x0000FF) << 8) + ((R) & 0x0000FF)))
#define ROUND_PRICE(A, P) ((int)((A) / P + 0.5))
#define NORM_PRICE(A, P) (((int)((A) / P + 0.5)) * P)

enum ENUM_POINT_SCALE
{
	POINT_SCALE_1 = 1,      // *1
	POINT_SCALE_10 = 10,    // *10
	POINT_SCALE_100 = 100,  // *100
};

enum ENUM_VP_BAR_STYLE
{
	VP_BAR_STYLE_LINE,        // Line
	VP_BAR_STYLE_BAR,         // Empty bar
	VP_BAR_STYLE_FILLED,      // Filled bar
	VP_BAR_STYLE_OUTLINE,     // Outline
	VP_BAR_STYLE_COLOR        // Color
};

enum ENUM_HG_DIRECTION
{
	HG_DIRECTION_LEFT = 0,   // Right to left
	HG_DIRECTION_RIGHT = 1,  // Left to right
};

enum ENUM_VP_SOURCE
{
	VP_SOURCE_TICKS = 0,   // Ticks

	VP_SOURCE_M1 = 1,      // M1 bars
	VP_SOURCE_M5 = 5,      // M5 bars
	VP_SOURCE_M15 = 15,    // M15 bars
	VP_SOURCE_M30 = 30,    // M30 bars
};

enum ENUM_TIME_SHIFT
{
	TIME_SHIFT_PLUS_720 = 720,     // +12:00
	TIME_SHIFT_PLUS_660 = 660,     // +11:00
	TIME_SHIFT_PLUS_600 = 600,     // +10:00
	TIME_SHIFT_PLUS_540 = 540,     // +9:00
	TIME_SHIFT_PLUS_480 = 480,     // +8:00
	TIME_SHIFT_PLUS_420 = 420,     // +7:00
	TIME_SHIFT_PLUS_360 = 360,     // +6:00
	TIME_SHIFT_PLUS_300 = 300,     // +5:00
	TIME_SHIFT_PLUS_240 = 240,     // +4:00
	TIME_SHIFT_PLUS_180 = 180,     // +3:00
	TIME_SHIFT_PLUS_120 = 120,     // +2:00
	TIME_SHIFT_PLUS_60 = 60,       // +1:00
	TIME_SHIFT_0 = 0,              // 0:00 (no shift)
	TIME_SHIFT_MINUS_60 = -60,     // -1:00
	TIME_SHIFT_MINUS_120 = -120,   // -2:00
	TIME_SHIFT_MINUS_180 = -180,   // -3:00
	TIME_SHIFT_MINUS_240 = -240,   // -4:00
	TIME_SHIFT_MINUS_300 = -300,   // -5:00
	TIME_SHIFT_MINUS_360 = -360,   // -6:00
	TIME_SHIFT_MINUS_420 = -420,   // -7:00
	TIME_SHIFT_MINUS_480 = -480,   // -8:00
	TIME_SHIFT_MINUS_540 = -540,   // -9:00
	TIME_SHIFT_MINUS_600 = -600,   // -10:00
	TIME_SHIFT_MINUS_660 = -660,   // -11:00
	TIME_SHIFT_MINUS_720 = -720,   // -12:00
};

/* Calculation */
input ENUM_TIMEFRAMES RangePeriod = PERIOD_D1;                  // Range period
input int RangeCount = 20;                                      // Range count
input ENUM_TIME_SHIFT TimeShift = TIME_SHIFT_0;                 // Time shift
input int ModeStep = 100;                                       // Mode step (points)
input ENUM_POINT_SCALE HgPointScale = POINT_SCALE_10;           // Point scale
input ENUM_APPLIED_VOLUME VolumeType = VOLUME_TICK;             // Volume type
input ENUM_VP_SOURCE DataSource = VP_SOURCE_M1;                 // Data source

/* Histogram */
input ENUM_VP_BAR_STYLE HgBarStyle = VP_BAR_STYLE_LINE;         // Bar style
input ENUM_HG_DIRECTION DrawDirection = HG_DIRECTION_RIGHT;     // Draw direction
input color HgColor = C'128,160,192';                           // Color 1
input color HgColor2 = C'128,160,192';                          // Color 2
input int HgLineWidth = 1;                                      // Line width

/* Levels */
input color ModeColor = clrBlue;                                // Mode color
input color MaxColor = clrNONE;                                 // Maximum color
input color MedianColor = clrNONE;                              // Median color
input color VwapColor = clrNONE;                                // VWAP color
input int ModeLineWidth = 1;                                    // Mode line width
input ENUM_LINE_STYLE StatLineStyle = STYLE_DOT;                // Median & VWAP line style

/* Service */
input string Id = "+vp";                                        // Identifier
bool ShowHorizon = true;                                  // Show data horizon
double Zoom = 0;                                          // Zoom (0=auto)
int WaitMilliseconds = 1000;                              // Wait milliseconds
uint RangeLength = 0;                                     // Range length (0=Range period) // íå ðåàëèçîâàíî

void OnInit()
{
	_prefix = Id + " " + IntegerToString(RangePeriod) + " ";
	_rangeCount = RangeCount > 0 ? RangeCount : 1;
	_hgPoint = _Point * HgPointScale;
	_modeStep = ModeStep / HgPointScale;

	ArrayFree(_drawHistory);

	// íàñòðîéêè îòîáðàæåíèÿ
	_hgBarStyle = HgBarStyle;
	_hgPointDigits = GetPointDigits(_hgPoint);

	_defaultHgColor1 = HgColor;
	_defaultHgColor2 = HgColor2;

	_hgLineWidth = HgLineWidth;

	_modeColor = ModeColor;
	_maxColor = MaxColor;
	_medianColor = MedianColor;
	_vwapColor = VwapColor;
	_modeLineWidth = ModeLineWidth;

	_statLineStyle = StatLineStyle;

	_showHg = !(ColorIsNone(_hgColor1) && ColorIsNone(_hgColor2));
	_showModes = !ColorIsNone(_modeColor);
	_showMax = !ColorIsNone(_maxColor);
	_showMedian = !ColorIsNone(_medianColor);
	_showVwap = !ColorIsNone(_vwapColor);

	_zoom = MathAbs(Zoom);
	_updateTimer = new MillisecondTimer(WaitMilliseconds, false);

	// ñäâèã íå ìîæåò áûòü áîëüøå RangePeriod
	_timeShiftSeconds = (((int)TimeShift * 60) % PeriodSeconds(RangePeriod));

	// êîððåêöèÿ ñäâèãà âïåð¸ä, åñëè îí îòðèöàòåëüíûé, ÷òîáû ðèñîâàëñÿ è ïîñëåäíèé äèàïàçîí
	if (_timeShiftSeconds < 0)
		_timeShiftSeconds += PeriodSeconds(RangePeriod);

	// òàéìôðåéì èñòî÷íèêà äàííûõ
	_dataPeriod = GetDataPeriod(DataSource);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{

	if (id == CHARTEVENT_CHART_CHANGE)
	{
		// åñëè öâåò ôîíà èçìåíèëñÿ, ïåðåðèñîâàòü âñå ãèñòîãðàììû
		if (UpdateAutoColors())
		{
			ArrayFree(_drawHistory);
			CheckTimer();
		}
	}
}

int OnCalculate(const int ratesTotal, const int prevCalculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tickVolume[], const long &volume[], const int &spread[])
{

	// åñëè öâåò ôîíà èçìåíèëñÿ, ïåðåðèñîâàòü âñå ãèñòîãðàììû
	if (UpdateAutoColors())
		ArrayFree(_drawHistory);

	CheckTimer();
	return(0);
}

void OnTimer()
{

	CheckTimer();
}

void OnDeinit(const int reason)
{
	ObjectsDeleteAll(0, _prefix);
	delete(_updateTimer);
}

void CheckTimer()
{
	// Âûêëþ÷èòü ðåçåðâíûé òàéìåð
	EventKillTimer();

	// Åñëè òàéìåð ñðàáîòàë, íàðèñîâàòü êàðòèíêó. Ëèáî ñðàçó, åñëè â ïðîøëûé ðàç áûëà ïðîáëåìà.
	if (_updateTimer.Check() || !_lastOK)
	{
		// Îáíîâèòü. Â ñëó÷àå íåóäà÷è ïîñòàâèòü òàéìåð íà 3 ñåêóíäû, ÷òîáû ïîïðîáîâàòü ñíîâà åù¸ ðàç.
		// 3 ñåêóíäû äîëæíî áûòü äîñòàòî÷íî äëÿ ïîäãðóçêè ïîñëåäíåé èñòîðèè. Èíà÷å âñ¸ ïðîñòî ïîâòîðèòñÿ åù¸ ÷åðåç 3.
		_lastOK = Update();

		if (!_lastOK)
			EventSetTimer(3);

		ChartRedraw();

		// ðàñ÷¸ò è ðèñîâàíèå ìîãóò áûòü äëèòåëüíûìè, ëó÷øå ïåðåçàïóñòèòü òàéìåð
		_updateTimer.Reset();
	}
	else
	{
		// Íà ñëó÷àé, åñëè ñâîé òàéìåð áîëüøå íå áóäåò ïðîâåðÿòüñÿ, äîáàâèòü ïðèíóäèòåëüíóþ ïðîâåðêó ÷åðåç 3 ñåêóíäû
		EventSetTimer(3);
	}
}

bool Update()
{
	// Ñîñòàâèòü ñïèñîê äèàïàçîíîâ
	datetime ranges[];
	ArraySetAsSeries(ranges, true);
	ArrayResize(ranges, _rangeCount);

	if (CopyTime(_Symbol, RangePeriod, 0, _rangeCount, ranges) != _rangeCount)
		return(false);

	// Åñëè RangePeriod - íåäåëÿ, ñäâèíóòü âñ¸ âïåð¸ä íà 1 äåíü, ò.ê. íåäåëÿ â MT íà÷èíàåòñÿ ñ âîñêðåñåíüÿ
	if (RangePeriod == PERIOD_W1)
	{
		for (int i = 0; i < _rangeCount; i++)
			ranges[i] += 1440 * 60;
	}

	/* Ïðîâåðèòü íàëè÷èå íåîáõîäèìûõ êîòèðîâîê. */
	int rangeLengthSeconds = RangeLength == 0 ? PeriodSeconds(RangePeriod) : (int)RangeLength * 60;

	datetime dataRates[];
	datetime rangesStart = ranges[_rangeCount - 1] + _timeShiftSeconds;
	datetime rangesEnd = ranges[0] + rangeLengthSeconds - 1 + _timeShiftSeconds;

	if (CopyTime(_Symbol, _dataPeriod, rangesStart, rangesEnd, dataRates) <= 0)
		return(false);

	// âðåìÿ òåêóùåãî áàðà
	MqlTick tick;
	if (!SymbolInfoTick(_Symbol, tick))
		return(false);

	datetime lastTickTime = tick.time;

	if (ShowHorizon)
	{
		datetime horizon = GetHorizon(DataSource, _dataPeriod);
		DrawHorizon(_prefix + "hz", horizon);
	}

	int modes[];
	double volumes[];
	double lowPrice;

	bool totalResult = true;

	for (int i = 0; i < _rangeCount; i++)
	{
		/* Ðàñ÷¸ò */

		// Ãðàíèöû äèàïàçîíà
		datetime rangeStart = ranges[i] + _timeShiftSeconds;

		if (TimeDayOfWeek(rangeStart) == SUNDAY)
			rangeStart -= 2 * 1440 * 60;

		// Åñëè ãèñòîãðàììà óæå áûëà óñïåøíî íàðèñîâàíà, ïðîïóñòèòü. Êðîìå êðàéíåé ïðàâîé.
		if ((i != 0) && (ArrayIndexOf(_drawHistory, rangeStart) != -1))
			continue;

		// êîíåö äèàïàçîíà ñ ó÷¸òîì ñäâèãà
		datetime rangeEnd;

		if (i == 0)
		{
			rangeEnd = ranges[i] + _timeShiftSeconds + rangeLengthSeconds - 1;
		}
		else
		{
			rangeEnd = ranges[i - 1] + _timeShiftSeconds - 1;

			if (TimeDayOfWeek(rangeEnd) == SUNDAY)
				rangeEnd -= 2 * 1440 * 60;
		}

		int barFrom, barTo;

		if (!GetRangeBars(rangeStart, rangeEnd, barFrom, barTo))
		{
			totalResult = false;
			// â ñëó÷àå îøèáêè ðèñîâàíèÿ îäíîé ãèñòîãðàììû, ïðîäîëæèòü ðèñîâàòü äðóãèå
			continue;
		}

		int count;

		if (DataSource == VP_SOURCE_TICKS)
			count = GetHgByTicks(rangeStart, rangeEnd, _hgPoint, _dataPeriod, VolumeType, lowPrice, volumes);
		else
			count = GetHg(rangeStart, rangeEnd, _hgPoint, _dataPeriod, VolumeType, lowPrice, volumes);

		if (count <= 0)
		{
			totalResult = false;
			// â ñëó÷àå îøèáêè ðèñîâàíèÿ îäíîé ãèñòîãðàììû, ïðîäîëæèòü ðèñîâàòü äðóãèå
			continue;
		}

		// äîáàâèòü ãèñòîãðàììó â ñïèñîê âûïîëíåííûõ, åñëè å¸ ïðàâàÿ ãðàíèöà ëåâåå òåêóùåãî òèêà
		if (rangeEnd < lastTickTime)
			ArrayAdd(_drawHistory, rangeStart, true);

		/* Îòîáðàæåíèå */

		// Óðîâíè
		int modeCount = _showModes ? HgModes(volumes, _modeStep, modes) : -1;
		int maxPos = _showMax ? ArrayMax(volumes) : -1;
		int medianPos = _showMedian ? ArrayMedian(volumes) : -1;
		int vwapPos = _showVwap ? HgVwap(volumes, lowPrice, _hgPoint) : -1;

		// ïðåôèêñ äëÿ êàæäîé ãèñòîãðàììû ñâîé
		string prefix = _prefix + (string)((int)rangeStart / PeriodSeconds(RangePeriod)) + " ";

		double maxVolume = volumes[ArrayMaximum(volumes)];

		// Ó÷åñòü íóëåâûå îáú¸ìàìû âñåõ áàðîâ èñòî÷íèêà
		if (maxVolume == 0)
			maxVolume = 1;

		// îïðåäåëèòü ìàñøòàá è íàïðàâëåíèå
		double zoom = _zoom > 0 ? _zoom : (barFrom - barTo) / maxVolume;

		if (DrawDirection == HG_DIRECTION_LEFT)
			Swap(barFrom, barTo);

		// Óäàëèòü ñòàðûå ëèíèè
		ObjectsDeleteAll(0, prefix);

		// Îòîáðàçèòü ãèñòîãðàììó
		DrawHg(prefix, lowPrice, volumes, barFrom, barTo, zoom, modes, maxPos, medianPos, vwapPos);
	}

	return(totalResult);
}

ENUM_DAY_OF_WEEK TimeDayOfWeek(const datetime time)
{
	MqlDateTime timeStruct;
	TimeToStruct(time, timeStruct);
	return (ENUM_DAY_OF_WEEK)timeStruct.day_of_week;
}

template <typename T>
int ArrayIndexOf(const T &arr[], const T value, const int startingFrom = 0)
{
	int size = ArraySize(arr);

	for (int i = startingFrom; i < size; i++)
	{
		if (arr[i] == value)
			return(i);
	}

	return(-1);
}

template <typename T>
int ArrayAdd(T &arr[], T value, const bool checkUnique = false, const int reserveSize = 100)
{
	int i;

	// Íàéòè ñóùåñòâóþùèé, åñëè íåîáõîäèìî
	if (checkUnique)
	{
		i = ArrayIndexOf(arr, value);

		if (i != -1)
			return(i);
	}

	// Äîáàâèòü íîâûé ýëåìåíò â ìàññèâ
	i = ArrayResize(arr, ArraySize(arr) + 1, reserveSize);

	if (i == -1)
		return(-1);

	i--;
	arr[i] = value;

	return(i);
}

template <typename T>
bool ArrayCheckRange(const T &arr[], int &start, int &count)
{
	int size = ArraySize(arr);

	// â ñëó÷àå ïóñòîãî ìàññèâà ðåçóëüòàò íåîïðåäåë¸í, íî âåðíóòü êàê îøèáî÷íûé
	if (size <= 0)
		return(false);

	// â ñëó÷àå íóëåâîãî äèàïàçîíà ðåçóëüòàò íåîïðåäåë¸í, íî âåðíóòü êàê îøèáî÷íûé
	if (count == 0)
		return(false);

	// ñòàðò âûõîäèò çà ãðàíèöû ìàññèâà
	if ((start > size - 1) || (start < 0))
		return(false);

	if (count < 0)
	{
		// åñëè êîëè÷åñòâî íå óêàçàíî, âåðíóòü âñ¸ îò start
		count = size - start;
	}
	else if (count > size - start)
	{
		// åñëè ýëåìåíòîâ íåäîñòàòî÷íî äëÿ óêàçàííîãî êîëè÷åñòâà, âåðíóòü ìàêñèìàëüíî âîçìîæíîå
		count = size - start;
	}

	return(true);
}

int ArrayMedian(const double &values[])
{
	int size = ArraySize(values);
	double halfVolume = Sum(values) / 2.0;

	double v = 0;

	// ïðîéòè ïî ãèñòîãðàììå è îñòàíîâèòüñÿ íà ñåðåäèíå ïî îáú¸ìó
	for (int i = 0; i < size; i++)
	{
		v += values[i];

		if (v >= halfVolume)
			return(i);
	}

	return(-1);
}

string TrimRight(string s, const ushort ch)
{
	int len = StringLen(s);

	// Íàéòè íà÷àëî âûðåçàåìîãî äî êîíöà ó÷àñòêà
	int cut = len;

	for (int i = len - 1; i >= 0; i--)
	{
		if (StringGetCharacter(s, i) == ch)
			cut--;
		else
			break;
	}

	if (cut != len)
	{
		if (cut == 0)
			s = "";
		else
			s = StringSubstr(s, 0, cut);
	}

	return(s);
}

string DoubleToString(const double d, const uint digits, const uchar separator)
{
	string s = DoubleToString(d, digits) + ""; //HACK: áåç +"" ôóíêöèÿ ìîæåò âåðíóòü ïóñòîå çíà÷åíèå (áèëä 697)

	if (separator != '.')
	{
		int p = StringFind(s, ".");

		if (p != -1)
			StringSetCharacter(s, p, separator);
	}

	return(s);
}

string DoubleToCompactString(const double d, const uint digits = 8, const uchar separator = '.')
{
	string s = DoubleToString(d, digits, separator);

	// óáðàòü íóëè â êîíöå äðîáíîé ÷àñòè
	if (StringFind(s, CharToString(separator)) != -1)
	{
		s = TrimRight(s, '0');
		s = TrimRight(s, '.');
	}

	return(s);
}

double MathRound(const double value, const double error)
{
	return(error == 0 ? value : MathRound(value / error) * error);
}

template <typename T>
void Swap(T &value1, T &value2)
{
	T tmp = value1;
	value1 = value2;
	value2 = tmp;
}

template <typename T>
T Sum(const T &arr[], int start = 0, int count = -1)
{
	if (!ArrayCheckRange(arr, start, count))
		return((T)NULL);

	T sum = (T)NULL;

	for (int i = start, end = start + count; i < end; i++)
		sum += arr[i];

	return(sum);
}

int GetPointDigits(const double point)
{
	if (point == 0)
		return(_Digits);

	return(GetPointDigits(point, _Digits));
}

int GetPointDigits(const double point, const int maxDigits)
{
	if (point == 0)
		return(maxDigits);

	string pointString = DoubleToCompactString(point, maxDigits);
	int pointStringLen = StringLen(pointString);
	int dotPos = StringFind(pointString, ".");

	// pointString => result:
	//   1230   => -1
	//   123    =>  0
	//   12.3   =>  1
	//   1.23   =>  2
	//   0.123  =>  3
	//   .123   =>  3

	return(dotPos < 0
		? StringLen(TrimRight(pointString, '0')) - pointStringLen
		: pointStringLen - dotPos - 1);
}

template <typename T>
int ArrayMax(const T &array[], const int start = 0, const int count = WHOLE_ARRAY)
{
	return(ArrayMaximum(array, start, count));
}

int HgModes(const double &values[], const int modeStep, int &modes[])
{
	int modeCount = 0;
	ArrayFree(modes);

	// èùåì ìàêñèìóìû ïî ó÷àñòêàì
	for (int i = modeStep, count = ArraySize(values) - modeStep; i < count; i++)
	{
		int maxFrom = i - modeStep;
		int maxRange = 2 * modeStep + 1;
		int maxTo = maxFrom + maxRange - 1;

		int k = ArrayMax(values, maxFrom, maxRange);

		if (k != i)
			continue;

		for (int j = i - modeStep; j <= i + modeStep; j++)
		{
			if (values[j] != values[k])
				continue;

			modeCount++;
			ArrayResize(modes, modeCount, count);
			modes[modeCount - 1] = j;
		}
	}

	return(modeCount);
}

int HgVwap(const double &volumes[], const double low, const double step)
{
	if (step == 0)
		return(-1);

	double vwap = 0;
	double totalVolume = 0;
	int size = ArraySize(volumes);

	for (int i = 0; i < size; i++)
	{
		double price = low + i * step;
		double volume = volumes[i];

		vwap += price * volume;
		totalVolume += volume;
	}

	if (totalVolume == 0)
		return(-1);

	vwap /= totalVolume;
	return((int)((vwap - low) / step + 0.5));
}

int iBarShiftOverride(string symbol, ENUM_TIMEFRAMES timeframe, datetime time, bool exact = false)
{
	if (time < 0)
		return(-1);

	datetime arr[];
	datetime time1;
	CopyTime(symbol, timeframe, 0, 1, arr);
	time1 = arr[0];

	if (CopyTime(symbol, timeframe, time, time1, arr) <= 0)
		return(-1);

	if (ArraySize(arr) > 2)
		return(ArraySize(arr) - 1);

	return(time < time1 ? 1 : 0);
}

datetime iTimeOverride(string symbol, ENUM_TIMEFRAMES timeframe, int index)
{
	if (index < 0)
		return(-1);

	datetime arr[];

	if (CopyTime(symbol, timeframe, index, 1, arr)<= 0)
		return(-1);

	return(arr[0]);
}

// ïîëó÷èòü (âû÷èñëèòü) ãèñòîãðàììó ïî òèêàì
int GetHgByTicks(const datetime timeFrom, const datetime timeTo, const double point, const ENUM_TIMEFRAMES dataPeriod, const ENUM_APPLIED_VOLUME appliedVolume, double &low, double &volumes[])
{
	// Îïðåäåëèòü êîëè÷åñòâî òèêîâ ïî ñóììàðíîìó òèêîâîìó îáú¸ìó áàðîâ äèàïàçîíà
	long tickVolumes[];
	int tickVolumeCount = CopyTickVolume(_Symbol, dataPeriod, timeFrom, timeTo, tickVolumes);

	if (tickVolumeCount <= 0)
		return(0);

	long tickVolumesTotal = Sum(tickVolumes);

	// Ñêîïèðîâàòü òèêè, íóæíû òîëüêî ñîâåðø¸ííûå ñäåëêè, íóæíà èíôîðìàöè òîëüêî ïî Last + îáú¸ì + âðåìÿ òèêà
	MqlTick ticks[];
	int tickCount = CopyTicks(_Symbol, ticks, COPY_TICKS_TRADE, timeFrom * 1000, (uint)tickVolumesTotal);

	// Íåò òèêîâ - íåò ãèñòîãðàììû
	if (tickCount <= 0)
	{
		return(0);
	}

	// Îïðåäåëèòü ìèíèìóì è ìàêñèìóì, ðàçìåð ìàññèâà ãèñòîãðàììû
	MqlTick tick = ticks[0];
	low = NORM_PRICE(tick.last, point);
	double high = low;
	long timeToMs = timeTo * 1000;

	for (int i = 1; i < tickCount; i++)
	{
		tick = ticks[i];

		// Èíîãäà ïîëó÷åííûå òèêè âûõîäÿò çà óêàçàííûé äèàïàçîí (îøèáêà â äàííûõ íà ñåðâåðå, íàïðèìåð).
		// Â òàêîì ñëó÷àå îáðåçàòü ëèøíåå. Ñàì ìàññèâ ìîæíî íå èçìåíÿòü, äîñòàòî÷íî óòî÷íèòü êîëè÷åñòâî ïðàâèëüíûõ òèêîâ.
		// Ïðåäïîëîæèòåëüíî ïðîáëåìû âûõîäà çà ëåâóþ ãðàíèöó íåò.
		if (tick.time_msc > timeToMs)
		{
			tickCount = i;
			break;
		}

		double tickLast = NORM_PRICE(tick.last, point);

		if (tickLast < low)
			low = tickLast;

		if (tickLast > high)
			high = tickLast;
	}

	int lowIndex = ROUND_PRICE(low, point);
	int highIndex = ROUND_PRICE(high, point);
	int hgSize = highIndex - lowIndex + 1; // êîëè÷åñòâî öåí â ãèñòîãðàììå
	ArrayResize(volumes, hgSize);
	ArrayInitialize(volumes, 0);

	// Ñëîæèòü âñå òèêè â îäíó ãèñòîãðàììó

	int pri;

	for (int j = 0; j < tickCount; j++)
	{
		tick = ticks[j];
		pri = ROUND_PRICE(tick.last, point) - lowIndex;

		// Åñëè íóæåí ðåàëüíûé îáú¸ì, áåð¸ì åãî èç èíôîðìàöèè ïî òèêó.
		// Åñëè íóæåí òèêîâûé îáú¸ì, òî äîñòàòî÷íî ó÷åñòü êàæäûé òèê ðîâíî îäèí ðàç.
		volumes[pri] += (appliedVolume == VOLUME_REAL) ? (double)tick.volume : 1;
	}

	return(hgSize);
}

// ïîëó÷èòü (âû÷èñëèòü) ãèñòîãðàììó ïî áàðàì, èìèòèðóÿ òèêè
int GetHg(const datetime timeFrom, const datetime timeTo, const double point, const ENUM_TIMEFRAMES dataPeriod, const ENUM_APPLIED_VOLUME appliedVolume, double &low, double &volumes[])
{
	// Ïîëó÷èòü áàðû òàéìôðåéìà ðàñ÷¸òà (îáû÷íî M1)
	MqlRates rates[];
	int rateCount = CopyRates(_Symbol, dataPeriod, timeFrom, timeTo, rates);

	if (rateCount <= 0)
		return(0);

	// Îïðåäåëèòü ìèíèìóì è ìàêñèìóì, ðàçìåð ìàññèâà ãèñòîãðàììû
	MqlRates rate = rates[0];
	low = NORM_PRICE(rate.low, point);
	double high = NORM_PRICE(rate.high, point);

	for (int i = 1; i < rateCount; i++)
	{
		rate = rates[i];

		double rateHigh =  NORM_PRICE(rate.high, point);
		double rateLow = NORM_PRICE(rate.low, point);

		if (rateLow < low)
			low = rateLow;

		if (rateHigh > high)
			high = rateHigh;
	}

	int lowIndex = ROUND_PRICE(low, point);
	int highIndex = ROUND_PRICE(high, point);
	int hgSize = highIndex - lowIndex + 1; // êîëè÷åñòâî öåí â ãèñòîãðàììå
	ArrayResize(volumes, hgSize);
	ArrayInitialize(volumes, 0);

	// Ñëîæèòü âñå òèêè âñåõ áàðîâ â îäíó ãèñòîãðàììó

	int pri, oi, hi, li, ci;
	double dv, v;

	for (int j = 0; j < rateCount; j++)
	{
		rate = rates[j];

		oi = ROUND_PRICE(rate.open, point) - lowIndex;
		hi = ROUND_PRICE(rate.high, point) - lowIndex;
		li = ROUND_PRICE(rate.low, point) - lowIndex;
		ci = ROUND_PRICE(rate.close, point) - lowIndex;

		v = (appliedVolume == VOLUME_REAL) ? (double)rate.real_volume : (double)rate.tick_volume;

		// èìèòàöèÿ òèêîâ âíóòðè áàðà
		if (ci >= oi)
		{
			/* áû÷üÿ ñâå÷à */

			// ñðåäíèé îáú¸ì êàæäîãî òèêà
			dv = v / (oi - li + hi - li + hi - ci + 1.0);

			// open --> low
			for (pri = oi; pri >= li; pri--)
				volumes[pri] += dv;

			// low+1 ++> high
			for (pri = li + 1; pri <= hi; pri++)
				volumes[pri] += dv;

			// high-1 --> close
			for (pri = hi - 1; pri >= ci; pri--)
				volumes[pri] += dv;
		}
		else
		{
			/* ìåäâåæüÿ ñâå÷à */

			// ñðåäíèé îáú¸ì êàæäîãî òèêà
			dv = v / (hi - oi + hi - li + ci - li + 1.0);

			// open ++> high
			for (pri = oi; pri <= hi; pri++)
				volumes[pri] += dv;

			// high-1 --> low
			for (pri = hi - 1; pri >= li; pri--)
				volumes[pri] += dv;

			// low+1 ++> close
			for (pri = li + 1; pri <= ci; pri++)
				volumes[pri] += dv;
		}
	}

	return(hgSize);
}

// Ïîëó÷èòü âðåìÿ ïåðâûõ äîñòóïíûõ äàííûõ
datetime GetHorizon(ENUM_VP_SOURCE dataSource, ENUM_TIMEFRAMES dataPeriod)
{
	if (dataSource == VP_SOURCE_TICKS)
	{
		MqlTick ticks[];
		int tickCount = CopyTicks(_Symbol, ticks, COPY_TICKS_INFO, 1, 1);

		if (tickCount <= 0)
			return ((datetime)(SymbolInfoInteger(_Symbol, SYMBOL_TIME) + 1));

		return(ticks[0].time);
	}

	return((datetime)(iTimeOverride(_Symbol, dataPeriod, Bars(_Symbol, dataPeriod) - 1)));
}

// Ïîëó÷èòü òàéìôðåéì èñòî÷íèêà äàííûõ
ENUM_TIMEFRAMES GetDataPeriod(ENUM_VP_SOURCE dataSource)
{
	switch (dataSource)
	{
		case VP_SOURCE_TICKS: return(PERIOD_M1); // äëÿ ïîëó÷åíèÿ ÷èñëà íåîáõîäèìûõ äëÿ çàãðóçêè òèêîâ

		case VP_SOURCE_M1:    return(PERIOD_M1);
		case VP_SOURCE_M5:    return(PERIOD_M5);
		case VP_SOURCE_M15:   return(PERIOD_M15);
		case VP_SOURCE_M30:   return(PERIOD_M30);
		default:              return(PERIOD_M1);
	}
}

bool ColorToRGB(const color c, int &r, int &g, int &b)
{
	// Åñëè öâåò çàäàí íåâåðíûé, ëèáî çàäàí êàê îòñóòñòâóþùèé, âåðíóòü false
	if (COLOR_IS_NONE(c))
		return(false);

	b = (c & 0xFF0000) >> 16;
	g = (c & 0x00FF00) >> 8;
	r = (c & 0x0000FF);

	return(true);
}

color MixColors(const color color1, const color color2, double mix, double step = 16)
{
	// Êîððåêöèÿ íåâåðíûõ ïàðàìåòðîâ
	step = PUT_IN_RANGE(step, 1.0, 255.0);
	mix = PUT_IN_RANGE(mix, 0.0, 1.0);

	int r1, g1, b1;
	int r2, g2, b2;

	// Ðàçáèòü íà êîìïîíåíòû
	ColorToRGB(color1, r1, g1, b1);
	ColorToRGB(color2, r2, g2, b2);

	// âû÷èñëèòü
	int r = PUT_IN_RANGE((int)MathRound(r1 + mix * (r2 - r1), step), 0, 255);
	int g = PUT_IN_RANGE((int)MathRound(g1 + mix * (g2 - g1), step), 0, 255);
	int b = PUT_IN_RANGE((int)MathRound(b1 + mix * (b2 - b1), step), 0, 255);

	return(RGB_TO_COLOR(r, g, b));
}

bool ColorIsNone(const color c)
{
	return(COLOR_IS_NONE(c));
}

class MillisecondTimer
{
	private: int _milliseconds;
	private: uint _lastTick;

	public: void MillisecondTimer(const int milliseconds, const bool reset = true)
	{
		_milliseconds = milliseconds;

		if (reset)
			Reset();
		else
			_lastTick = 0;
	}

	public: bool Check()
	{
		// ïðîâåðèòü îæèäàíèå
		uint now = getCurrentTick();
		bool stop = now >= _lastTick + _milliseconds;

		// ñáðàñûâàåì òàéìåð
		if (stop)
			_lastTick = now;

		return(stop);
	}

	public: void Reset()
	{
		_lastTick = getCurrentTick();
	}

	private: uint getCurrentTick() const
	{
		return(GetTickCount());
	}

};

void ObjectDisable(const long chartId, const string name)
{
	ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, true);
	ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
}

int GetTimeBarRight(datetime time, ENUM_TIMEFRAMES period = PERIOD_CURRENT)
{
	int bar = iBarShiftOverride(_Symbol, period, time);
	datetime t = iTimeOverride(_Symbol, period, bar);

	if ((t != time) && (bar == 0))
	{
		// âðåìÿ çà ïðåäåëàìè äèàïàçîíà
		bar = (int)((iTimeOverride(_Symbol, period, 0) - time) / PeriodSeconds(period));
	}
	else
	{
		// ïðîâåðèòü, ÷òîáû áàð áûë íå ñëåâà ïî âðåìåíè
		if (t < time)
			bar--;
	}

	return(bar);
}

// ïîëó÷èòü âðåìÿ ïî íîìåðó áàðà ñ ó÷åòîì âîçìîæíîãî âûõîäà çà äèàïàçîí áàðîâ (íîìåð áàðà ìåíüøå 0)
datetime GetBarTime(const int shift, ENUM_TIMEFRAMES period = PERIOD_CURRENT)
{
	if (shift >= 0)
		return(iTimeOverride(_Symbol, period, shift));
	else
		return(iTimeOverride(_Symbol, period, 0) - shift * PeriodSeconds(period));
}

// íàðèñîâàòü ëèíèþ ãîðèçîíòà äàííûõ
void DrawHorizon(const string lineName, const datetime time)
{
	DrawVLine(lineName, time, Red, 1, STYLE_DOT, false);
	ObjectDisable(0, lineName);
}

// íàðèñîâàòü âåðòèêàëüíóþ ëèíèþ
void DrawVLine(const string name, const datetime time1, const color lineColor, const int width, const int style, const bool back)
{
	if (ObjectFind(0, name) >= 0)
		ObjectDelete(0, name);

	ObjectCreate(0, name, OBJ_VLINE, 0, time1, 0);
	ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
	ObjectSetInteger(0, name, OBJPROP_BACK, back);
	ObjectSetInteger(0, name, OBJPROP_STYLE, style);
	ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

// íàðèñîâàòü áàð ãèñòîãðàììû
void DrawBar(const string name, const datetime time1, const datetime time2, const double price,
	const color lineColor, const int width, const ENUM_VP_BAR_STYLE barStyle, const ENUM_LINE_STYLE lineStyle, bool back)
{
	ObjectDelete(0, name);

	if (barStyle == VP_BAR_STYLE_BAR)
	{
		ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price - _hgPoint / 2.0, time2, price + _hgPoint / 2.0);

	}
	else if ((barStyle == VP_BAR_STYLE_FILLED) || (barStyle == VP_BAR_STYLE_COLOR))
	{
		ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price - _hgPoint / 2.0, time2, price + _hgPoint / 2.0);
	}
	else if (barStyle == VP_BAR_STYLE_OUTLINE)
	{
		ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price + _hgPoint);
	}
	else
	{
		ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
	}

	SetBarStyle(name, lineColor, width, barStyle, lineStyle, back);
}

// óñòàíîâèòü ñòèëü áàðà
void SetBarStyle(const string name, const color lineColor, const int width, const ENUM_VP_BAR_STYLE barStyle, const ENUM_LINE_STYLE lineStyle, bool back)
{
	ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
	ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
	ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
	ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
	ObjectSetInteger(0, name, OBJPROP_WIDTH, lineStyle == STYLE_SOLID ? width : 1);

	ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
	ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

	ObjectSetInteger(0, name, OBJPROP_BACK, back);
	ObjectSetInteger(0, name, OBJPROP_FILL, (barStyle == VP_BAR_STYLE_FILLED) || (barStyle == VP_BAR_STYLE_COLOR));
}

// íàðèñîâàòü óðîâåíü
void DrawLevel(const string name, const double price)
{
	ObjectDelete(0, name);
	ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

	ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
	ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
	ObjectSetInteger(0, name, OBJPROP_COLOR, _modeLevelColor);
	ObjectSetInteger(0, name, OBJPROP_STYLE, _modeLevelStyle);
	ObjectSetInteger(0, name, OBJPROP_WIDTH, _modeLevelStyle== STYLE_SOLID ? _modeLevelWidth : 1);

	// íå äîëæåí áûòü ôîíîì, èíà÷å íå áóäåò îòîáðàæåíà öåíà ñïðàâà
	ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

// íàðèñîâàòü ãèñòîãðàììó
void DrawHg(const string prefix, const double lowPrice, const double &volumes[], const int barFrom, const int barTo,
	double zoom, const int &modes[], const int max = -1, const int median = -1, const int vwap = -1)
{
	if (ArraySize(volumes) == 0)
		return;

	if (barFrom > barTo)
		zoom = -zoom;

	color cl = _hgColor1;
	double maxValue = volumes[ArrayMaximum(volumes)];

	// Ó÷åñòü âîçìîæíîñòü íóëåâûõ çíà÷åíèé âñåõ áàðîâ
	if (maxValue == 0)
		maxValue = 1;

	double volume;
	double nextVolume = 0;
	bool isOutline = _hgBarStyle == VP_BAR_STYLE_OUTLINE;

	int bar1 = barFrom;
	int bar2 = barTo;
	int modeBar2 = barTo;

	for (int i = 0, size = ArraySize(volumes); i < size; i++)
	{
		double price = NormalizeDouble(lowPrice + i * _hgPoint, _hgPointDigits);
		string priceString = DoubleToString(price, _hgPointDigits);
		string name = prefix + priceString;
		volume = volumes[i];

		if (isOutline)
		{
			if (i < size - 1)
			{
				nextVolume = volumes[i + 1];
				bar1 = (int)(barFrom + volume * zoom);
				bar2 = (int)(barFrom + nextVolume * zoom);
				modeBar2 = bar1;
			}
		}
		else if (_hgBarStyle != VP_BAR_STYLE_COLOR)
		{
			bar2 = (int)(barFrom + volume * zoom);
			modeBar2 = bar2;
		}

		datetime timeFrom = GetBarTime(barFrom);
		datetime timeTo = GetBarTime(barTo);
		datetime t1 = GetBarTime(bar1);
		datetime t2 = GetBarTime(bar2);
		datetime mt2 = GetBarTime(modeBar2);

		// Ïðè ñîâïàäåíèè íåñêîëüêèõ óðîâíåé ðèñîâàòü òîëüêî îäèí â ïðèîðèòåòå: max, median, vwap, mode.
		// Åñëè íè÷åãî íå ñîâïàäàåò, íàðèñîâàòü îáû÷íûé áàð.

		if (_showModeLevel && (ArrayIndexOf(modes, i) != -1))
			DrawLevel(name + " level", price);

		// Â ðåæèìå êîíòóðà ïîñëåäíèé áàð íå ðèñóåòñÿ
		if (_showHg && !(isOutline && (i == size - 1)))
		{
			if (_hgColor1 != _hgColor2)
				cl = MixColors(_hgColor1, _hgColor2, (isOutline ? MathMax(volume, nextVolume) : volume) / maxValue, 8);

			DrawBar(name, t1, t2, price, cl, _hgLineWidth, _hgBarStyle, STYLE_SOLID, true);
		}

		if (_showMedian && (i == median))
		{
			DrawBar(name + " median", timeFrom, timeTo, price, _medianColor, _modeLineWidth, VP_BAR_STYLE_LINE, _statLineStyle, false);
		}
		else if (_showVwap && (i == vwap))
		{
			DrawBar(name + " vwap", timeFrom, timeTo, price, _vwapColor, _modeLineWidth, VP_BAR_STYLE_LINE, _statLineStyle, false);
		}
		else if ((_showMax && (i == max)) || (_showModes && (ArrayIndexOf(modes, i) != -1)))
		{
			color modeColor = (_showMax && (i == max)) ? _maxColor : _modeColor;

			if (_hgBarStyle == VP_BAR_STYLE_LINE)
				DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_LINE, STYLE_SOLID, false);
			else if (_hgBarStyle == VP_BAR_STYLE_BAR)
				DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_BAR, STYLE_SOLID, false);
			else if (_hgBarStyle == VP_BAR_STYLE_FILLED)
				DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_FILLED, STYLE_SOLID, false);
			else if (_hgBarStyle == VP_BAR_STYLE_OUTLINE)
				DrawBar(name + "+", timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_LINE, STYLE_SOLID, false);
			else if (_hgBarStyle == VP_BAR_STYLE_COLOR)
				DrawBar(name, timeFrom, mt2, price, modeColor, _modeLineWidth, VP_BAR_STYLE_FILLED, STYLE_SOLID, false);
		}
	}
}

// ïîëó÷èòü äèàïàçîí áàðîâ â òåêóùåì ÒÔ (äëÿ ðèñîâàíèÿ)
bool GetRangeBars(const datetime timeFrom, const datetime timeTo, int &barFrom, int &barTo)
{
	barFrom = GetTimeBarRight(timeFrom);
	barTo = GetTimeBarRight(timeTo);
	return(true);
}

// Îáíîâèòü öâåòà, âû÷èñëÿåìûå àâòîìàòè÷åñêè. Åñëè îáíîâëåíèå ïðîèçîøëî, âåðíóòü true, èíà÷å false
bool UpdateAutoColors()
{
	if (!_showHg)
		return(false);

	bool isNone1 = ColorIsNone(_defaultHgColor1);
	bool isNone2 = ColorIsNone(_defaultHgColor2);

	if (isNone1 && isNone2)
		return(false);

	color newBgColor = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

	if (newBgColor == _prevBackgroundColor)
		return(false);

	_hgColor1 = isNone1 ? newBgColor : _defaultHgColor1;
	_hgColor2 = isNone2 ? newBgColor : _defaultHgColor2;

	_prevBackgroundColor = newBgColor;
	return(true);
}

string _prefix;
string _tfn;
string _ttn;

// èñòîðèÿ ðèñîâàíèÿ
datetime _drawHistory[];
// ïîñëåäíèé çàïóñê óñïåøíûé
bool _lastOK = false;

// ìèíèìàëüíîå èçìåíåíèå öåíû äëÿ îòîáðàæåíèÿ ãã
int _modeStep = 0;

color _prevBackgroundColor = clrNONE;

int _rangeCount;

ENUM_VP_BAR_STYLE _hgBarStyle;
double _hgPoint;
int _hgPointDigits;

color _defaultHgColor1;
color _defaultHgColor2;
color _hgColor1;
color _hgColor2;
int _hgLineWidth;

color _modeColor;
color _maxColor;
color _medianColor;
color _vwapColor;
int _modeLineWidth;

ENUM_LINE_STYLE _statLineStyle;

color _modeLevelColor;
ENUM_LINE_STYLE _modeLevelStyle;
int _modeLevelWidth;

bool _showHg;
bool _showModes;
bool _showMax;
bool _showMedian;
bool _showVwap;
bool _showModeLevel;

double _zoom;

int _firstVisibleBar = 0;
int _lastVisibleBar = 0;

MillisecondTimer *_updateTimer;

bool _isTimeframeEnabled = false;

int _timeShiftSeconds = 0;
ENUM_TIMEFRAMES _dataPeriod;

/*

Ñïèñîê èçìíåíåíèé

6.0
	* äîáàâëåíî: íîâûé ïàðàìåòð "Data source" äëÿ óêàçàíèÿ èñòî÷íèêà äàííûõ - òàéìôðåéìû M1, M5, M15 èëè (òîëüêî â MT5) òèêè.
	* èçìåíåíî: ïàðàìåòð "Point scale" ïåðåíåñ¸í âûøå â ñïèñêå ïàðàìåòðîâ
	* èçìåíåíî: ïàðàìåòð "Bar style" ïåðåíåñ¸í âûøå â ñïèñêå ïàðàìåòðîâ

5.8
	* èñïðàâëåíî: ãèñòîãðàììà íå îòîáðàæàåòñÿ, åñëè åñòü õîòÿ áû îäèí áàð ñ íóëåâûì îáú¸ìîì íà òàéìôðåéìå èñòî÷íèêà äàííûõ

5.7
	* VP:
		* èñïðàâëåíî: ïðè "Range period" = "1 Week" ãèñòîãðàììû ñìåùàëèñü íà äåíü âëåâî

5.6
	* VP-Range:
		* èñïðàâëåíî: íå îáíîâëÿåòñÿ ãèñòîãðàììà â ðåæèìå "Last minutes"
		* èñïðàâëåíî: íå ó÷èòûâàåòñÿ ïîñëåäíÿÿ ìèíóòà â ðåæèìå "Last minutes"

5.5
	* èçìåíåíû ññûëêè íà ñàéò
	* ñïèñîê èçìåíåíèé â êîäå

5.4
	* èñïðàâëåíà ìåäèàíà â MT4

5.3
	* èñïðàâëåíî: â MT4 ïðè ðèñîâàíèè ïóñòûìè ïðÿìîóãîëüíèêàìè ïëîõî áûëî âèäíî ìîäû èç-çà íàëîæåíèÿ áàðîâ
	* ñòèëü áàðîâ ïî óìîë÷àíèþ èçìåí¸í íà ëèíèè

5.2
	* VP-Range:
		* èñïðàâëåíî: â ðåæèìå "Minutes to line" íå âûäåëÿåòñÿ ïðàâàÿ ãðàíèöà, íî âûäåëÿåòñÿ ëåâàÿ, äîëæíî áûòü íàîáîðîò
		* èñïðàâëåíî: ïîñëå ïåðåêëþ÷åíèÿ ðåæèìà ñ "Minutes to line" íà "Between lines" íå âûäåëÿåòñÿ îäíà èç ãðàíèö

5.1
	* èñïðàâëåíî èãíîðèðîâàíèå îòîáðàæåíèÿ íà îïðåäåë¸ííûõ òàéìôðåìàõ â MT4 (îáõîä áàãà â MT4)

5.0
	* óâåëè÷åíû òàéìàóòû ïåðåðèñîâêè äëÿ ñíèæåíèÿ íàãðóçêè
	* òîëüêî VP:
		* âðåìåííîé ñäâèã îò -12 äî +12 ÷àñîâ ñ øàãîì 1 ÷àñ äëÿ êîìïåíñàöèè ñäâèãà ÷àñîâîãî ïîÿñà ó áðîêåðà
		* ïî óìîë÷àíèþ ìåäèàíà è VWAP âûêëþ÷åíû

4.0
	* èíäèêàòîð ïåðåèìåíîâàí íà VP (ñîêðàùåíèå îò Volume Profile)
	* äîáàâëåíà âåðñèÿ äëÿ MetaTrader 5 ñ ìèíèìàëüíûìè îòëè÷èÿìè â êîäå îò âåðñèè äëÿ MetaTrader 4
	* äîáàâëåíî: âòîðîé öâåò ãèñòîãðàììû äëÿ ðèñîâàíèÿ ãðàäèåíòîì
	* äîáàâëåíî: òèïû ãèñòîãðàìì Outline (êîíòóð) è Color (öâåò)
	* äîáàâëåíî: óðîâíè VWAP (ñðåäíåâçâåøåííàÿ ïî îáú¸ìó öåíà) è Median (ìåäèàíà)
	* äîáàâëåíî: ðó÷íîå óêàçàíèå ìàñøòàáà ïóíêòà
	* äîáàâëåíî: VP-Range: ðàñïîëîæåíèå ãèñòîãðàììû âíóòðè äèàïàçîíà
	* äîáàâëåíî: VP: îòîáðàæåíèå ãèñòîãðàìì ñïðàâà íàëåâî
	* èçìåíåíî: Mode step òåïåðü ñëåäóåò óêàçûâàòü â 10 ðàç áîëüøå äëÿ òîãî æå ðåçóëüòàòà, ýòî ñäåëàíî äëÿ áîëüøåé òî÷íîñòè íà íåáîëüøèõ äèàïàçîíàõ
	* èçìåíåíî: VP: äàííûå ïîñëåäíåãî áàðà òåïåðü ó÷èòûâàþòñÿ
	* èçìåíåíî: VP-Range: â ðåæèìàõ îòîáðàæåíèÿ îò ãðàíèö îêíà è ãðàíèö äèàïàçîíà íàðóæó øèðèíà ãèñòîãðàììû óâåëè÷åíà ñ 10% äî 15% îò ðàçìåðîâ ãðàôèêà, â îñòàëüíûõ ñëó÷àÿõ (âíóòðè ãðàíèö äèàïàçîíà) øèðèíà ðàâíà øèðèíå äèàïàçîíà

3.2
	* èñïðàâëåíî: ïðè îòêðûòèè íà ãðàôèêå áåç èñòîðèè ïîÿâëÿåòñÿ îøèáêà "...array out of range in..."
	* èçìåíåíî: ëèíèÿ ãîðèçîíòà ñïðÿòàíà èç ñïèñêà îáúåêòîâ è îòêëþ÷åíà äëÿ âûáîðà

3.1
	* èñïðàâëåíî: ïðè îáíîâëåíèè ïî ïîñëåäíèì äàííûì ìîãóò îñòàâàòüñÿ ñòàðûå ìîäû è ìàêñèìóìû
	* äîáàâëåíî: TPO-Range òåïåðü îáíîâëÿåòñÿ ñðàçó ïîñëå ïåðåìåùåíèÿ ãðàíèö â ñîîòâåòñòâóùèõ ðåæèìàõ

3.0
	* ñêðûòû íåäîêóìåíòèðîâàííûå ïàðàìåòðû DataPeriod è PriceStep (áûëè ïîêàçàíû ïî îøèáêå)
	* èñïîëüçîâàíèå íîâûõ âîçìîæíîñòåé MetaTrader 4 è îïòèìèçàöèÿ ïîä íåãî:
		* óëó÷øåíû îòîáðàæàåìûå íàçâàíèÿ ïàðàìåòðîâ
		* ïåðå÷èñëÿåìûå ïàðàìåòðû (ðåæèìû, ñòèëè, ïåðèîäû) ðåàëèçîâàíû â âèäå ñïèñêîâ âûáîðà, èõ ÷èñëîâûå çíà÷åíèÿ îñòàëèñü ïðåæíèìè
		* ëèíèè ãèñòîãðàìì íåëüçÿ âûáðàòü ìûøêîé (íå ìåøàþòñÿ ñðåäè äðóãèõ èíäèêàòîðîâ è ðàçìåòêè)
		* îïòèìèçàöèÿ ïîñëå èçìåíåíèé â ðàáîòå ôóíêöèè ArrayCopyRates()
		* ïîääåðæêà ðåàëüíûõ îáúåìîâ, åñëè îíè äîñòóïíû
	* èñïðàâëåí ïàðàìåòð ModeStep, òåïåðü îí ëó÷øå ðåàãèðóåò íà èçìåíåíèÿ
	* óäàëåíèå çà ñîáîé ëèíèé äèàïàçîíà â TPO-Range, â îäíîì èç ïðåäûäóùèõ îáíîâëåíèé MetaTrader èñïðàâëåíà îøèáêà, ìåøàþùàÿ äåëàòü ýòî
	* óäàëåíà ñêðûòàÿ ïîääåðæêà íåñêîëüêèõ ìåòîäîâ èìèòàöèè òèêîâ, îñòàâëåí òîëüêî íàèáîëåå òî÷íûé
	* â ðåæèìå 1 (Last minutes) TPO-Range ëèíèè âûáîðà/îòîáðàæåíèÿ äèàïàçîíà áîëüøå íå ïîêàçûâàþòñÿ

2.6
	* ñîâìåñòèìîñòü ñ MetaTrader âåðñèè 4.00 Build 600 è íîâåå

2.5.7491
	* â íåêîòîðûõ ðåæèìàõ â ñòèëå ïî óìîë÷àíèþ (HGStyle=1) ïðè ñæàòèè ãðàôèêà ïî âåðòèêàëè èñ÷åçàåò èçîáðàæåíèå ëîêàëüíûõ ìàêñèìóìîâ
	* óäàëåíî èç-çà îøèáêè â ÌÒ: TPO-Range - ïðè óäàëåíèè èíäèêàòîðà óäàëÿþòñÿ è ëèíèè ãðàíèö (áûëî äîáàâëåíî â 2.4.7290)

2.5.7484
	* â ñòèëå ïî óìîë÷àíèþ (HGStyle=1) ïðè ñæàòèè ãðàôèêà ïî âåðòèêàëè èñ÷åçàåò èçîáðàæåíèå ëîêàëüíûõ ìàêñèìóìîâ

2.5.7473
	* íàçâàíèÿ èíäèêàòîðîâ èçìåíåíû â ñîîòâåòñòâèè ñ ðàñïðîñòðàí¸ííûì íàçâàíèåì ìåòîäèêè ðàñ÷¸òà, ñõîæåé ñ äàííîé
	* äîáàâëåí ïàðàìåòð HGStyle: 0 - ðèñîâàòü ëèíèÿìè, 1 - ðèñîâàòü ïóñòûìè ïðÿìîóãîëüíèêàìè (çíà÷åíèå ïî óìîë÷àíèþ), 2 - îáû÷íûå ïðÿìîóãîëüíèêè (ðåæèì ïîëåçåí ïðè íàëîæåíèè íåñêîëüêèõ èíäèêàòîðîâ TPO äðóã íà äðóãà)

2.4.7290
	* èñïðàâëåíî: íå óäàëÿþòñÿ ñòàðûå ìîäû ïðè èñïîëüçîâàíèè íà ìåíÿþùèõñÿ äàííûõ
	* èç íàáîðà èñêëþ÷¸í ñêðèïò +FindVL
	* èñïðàâëåíî: ïðè âêëþ÷åííîé ìàêñèìàëüíîé ìîäå è îòêëþ÷åííûõ îñòàëüíûõ ïîêàçûâàþòñÿ âñå
	* +VL - ïðè óäàëåíèè èíäèêàòîðà óäàëÿþòñÿ è ëèíèè ãðàíèö

2.3.6704
	* ïîëíîñòüþ óáðàí ðåæèì ðàáîòû ÷åðåç vlib2.dll
	* èñïðàâëåíî: ïðè îòêëþ÷åííûõ ìîäàõ, íî âêëþ÷åííîé ìàêñèìàëüíîé, ìàêñèìàëüíàÿ íå ðèñîâàëàñü
	* +MP - ïîêàç ìàêñèìàëüíîé ìîäû ïî óìîë÷àíèþ îòêëþ÷åí
	* èñïðàâëåíî: +VL - ïðè îòêëþ÷åííûõ ìîäàõ, íî âêëþ÷åííûõ óðîâíÿõ, óðîâíè íå ðèñîâàëèñü

2.2.6294
	* ðåæèì ðàáîòû áåç vlib2.dll
	* óáðàíû ëèøíèå ìåòîäû ïîèñêà ìîä
	* ïàðàìåòð Smooth ïåðåèìåíîâàí â ModeStep
	* êîä èç +mpvl.mqh ïåðåíåñåí â îñíîâíûå ôàéëû (óïðîùåíèå óñòàíîâêè è ðàñïðîñòðàíåíèÿ)

2.1
	* èñïðàâëåíî: îøèáêà â ðàñ÷åòàõ
	* óáðàíû ëèøíèå ìåòîäû ðàñ÷åòà (ñêðûòûé ïàðàìåòð TickMethod)
	* èñïðàâëåíî: àâòîîïðåäåëåíèå ìàñøòàáà Smooth ïðè ðàáîòå íà ïÿòèçíàêå
	* äîáàâëåíû îïöèè â ñêðèïòå +FindVL

2.0
	* ñóùåñòâåííî óâåëè÷åíà ñêîðîñòü ðàáîòû
	* îïòèìèçèðîâàí íàáîð ïàðàìåòðîâ

1-18 (1.1-1.18)
	* òåñòîâûå âåðñèè, ðàçëè÷àþùèåñÿ ïî ôóíêöèîíàëó è ïàðàìåòðàì

*/

/*

Copyright (c) FXcoder. All rights reserved.

Ðàçðåøàåòñÿ ïîâòîðíîå ðàñïðîñòðàíåíèå è èñïîëüçîâàíèå êàê â âèäå èñõîäíîãî êîäà, òàê è â äâîè÷íîé ôîðìå, ñ èçìåíåíèÿìè
èëè áåç, ïðè ñîáëþäåíèè ñëåäóþùèõ óñëîâèé:

    * Ïðè ïîâòîðíîì ðàñïðîñòðàíåíèè èñõîäíîãî êîäà äîëæíî îñòàâàòüñÿ óêàçàííîå âûøå óâåäîìëåíèå îá àâòîðñêîì ïðàâå,
      ýòîò ñïèñîê óñëîâèé è ïîñëåäóþùèé îòêàç îò ãàðàíòèé.

    * Ïðè ïîâòîðíîì ðàñïðîñòðàíåíèè äâîè÷íîãî êîäà äîëæíà ñîõðàíÿòüñÿ óêàçàííàÿ âûøå èíôîðìàöèÿ îá àâòîðñêîì ïðàâå, ýòîò
      ñïèñîê óñëîâèé è ïîñëåäóþùèé îòêàç îò ãàðàíòèé â äîêóìåíòàöèè è/èëè â äðóãèõ ìàòåðèàëàõ, ïîñòàâëÿåìûõ ïðè
      ðàñïðîñòðàíåíèè.

    * Íè íàçâàíèå FXcoder, íè èìåíà åå ñîòðóäíèêîâ íå ìîãóò áûòü èñïîëüçîâàíû â êà÷åñòâå ïîääåðæêè èëè ïðîäâèæåíèÿ
      ïðîäóêòîâ, îñíîâàííûõ íà ýòîì ÏÎ áåç ïðåäâàðèòåëüíîãî ïèñüìåííîãî ðàçðåøåíèÿ.

Ýòà ïðîãðàììà ïðåäîñòàâëåíà âëàäåëüöàìè àâòîðñêèõ ïðàâ è/èëè äðóãèìè ñòîðîíàìè «êàê îíà åñòü» áåç êàêîãî-ëèáî âèäà
ãàðàíòèé, âûðàæåííûõ ÿâíî èëè ïîäðàçóìåâàåìûõ, âêëþ÷àÿ, íî íå îãðàíè÷èâàÿñü èìè, ïîäðàçóìåâàåìûå ãàðàíòèè êîììåð÷åñêîé
öåííîñòè è ïðèãîäíîñòè äëÿ êîíêðåòíîé öåëè. Íè â êîåì ñëó÷àå íè îäèí âëàäåëåö àâòîðñêèõ ïðàâ è íè îäíî äðóãîå ëèöî,
êîòîðîå ìîæåò èçìåíÿòü è/èëè ïîâòîðíî ðàñïðîñòðàíÿòü ïðîãðàììó, êàê áûëî ñêàçàíî âûøå, íå íåñ¸ò îòâåòñòâåííîñòè, âêëþ÷àÿ
ëþáûå îáùèå, ñëó÷àéíûå, ñïåöèàëüíûå èëè ïîñëåäîâàâøèå óáûòêè, âñëåäñòâèå èñïîëüçîâàíèÿ èëè íåâîçìîæíîñòè èñïîëüçîâàíèÿ
ïðîãðàììû (âêëþ÷àÿ, íî íå îãðàíè÷èâàÿñü ïîòåðåé äàííûõ, èëè äàííûìè, ñòàâøèìè íåïðàâèëüíûìè, èëè ïîòåðÿìè ïðèíåñåííûìè
èç-çà âàñ èëè òðåòüèõ ëèö, èëè îòêàçîì ïðîãðàììû ðàáîòàòü ñîâìåñòíî ñ äðóãèìè ïðîãðàììàìè), äàæå åñëè òàêîé âëàäåëåö èëè
äðóãîå ëèöî áûëè èçâåùåíû î âîçìîæíîñòè òàêèõ óáûòêîâ.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following
      disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
      following disclaimer in the documentation and/or other materials provided with the distribution.

    * Neither the name of the FXcoder nor the names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

This software is provided by the copyright holders and contributors "as is" and any express or implied warranties,
including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose are
disclaimed. In no event shall the copyright holder or contributors be liable for any direct, indirect, incidental,
special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or
services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability,
whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of
this software, even if advised of the possibility of such damage.

*/

// 2016-04-18 18:51:02 UTC. MQLMake 1.42. © FXcoder