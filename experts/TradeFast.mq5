//+------------------------------------------------------------------+
//|                                                    TradeFast.mq5 |
//|                               Copyright 2025, Maxime Bourdouxhe. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Maxime Bourdouxhe."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>

#define PANEL_WIDTH 350
#define PANEL_HEIGHT 220
#define BUTTON_WIDTH 100
#define BUTTON_HEIGHT 20
#define BUTTON_CLOSE_ALL_WIDTH 300
#define EDIT_WIDTH 80
#define EDIT_HEIGHT 20
#define LABEL_HEIGHT 20
#define GAP 10

//+------------------------------------------------------------------+
//| Trade Panel Class                                                |
//+------------------------------------------------------------------+
class CTradePanel : public CAppDialog {
  private:
    CTrade m_trade;

    CButton m_buy_btn;
    CButton m_sell_btn;
    CButton m_close_all_btn;

    double tp_pts, sl_pts, risk;

    virtual void GetEditValues();
    virtual double CalculVolume(double number_points);

  public:
    CTradePanel(void);
    ~CTradePanel(void);

    virtual bool Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
    void Toggle();

  protected:
    long chart;
    int  subwin;

    CLabel m_risk_label;
    CLabel m_sl_label;
    CLabel m_tp_label;
    CLabel m_sl_error_label;
    CLabel m_tp_error_label;

    CEdit m_risk_edit;
    CEdit m_tp_edit;
    CEdit m_sl_edit;

    virtual void OnClickBuy();
    virtual void OnClickSell();
    virtual void OnClickCloseAll();

    // Helper: Create a text label
    bool CreateLabelEx(CLabel &label, int x, int y, int height, string label_name, string text, color clr) {
        string unique_name = m_name + label_name;

        if(!label.Create(chart, unique_name, m_subwin, x, y, x, y+height))
            return false;

        if(!Add(label))
            return false;

        if(!label.Text(text))
            return false;

        label.Color(clr);
        return true;
    }

    // Helper: Create and add a button control
    bool CreateButton(CButton &button, string name, int x, int y, int w = BUTTON_WIDTH, int h = BUTTON_HEIGHT, color clr = clrWhite) {
        if(!button.Create(chart, name, subwin, x, y, x+w, y+h))
            return false;

        button.Text(name);
        button.Color(clr);

        if(!Add(button))
            return false;
        return true;
    }

    // Helper: Create and add an edit control
    bool CreateEdit(CEdit &edit, string name, int x, int y, int w = EDIT_WIDTH, int h = EDIT_HEIGHT) {
        if(!edit.Create(chart, name, subwin, x, y, x+w, y+h))
            return false;

        if(!Add(edit))
            return false;
        return true;
    }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradePanel::CTradePanel(void) {
    m_trade.SetExpertMagicNumber(12345);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradePanel::~CTradePanel(void) {
}

//+------------------------------------------------------------------+
//| Create                                                           |
//+------------------------------------------------------------------+
bool CTradePanel::Create(const long cchart,const string name,const int ssubwin,const int x1,const int y1,const int x2,const int y2) {
    if(!CAppDialog::Create(cchart, name, ssubwin, x1, y1, x2, y2))
        return(false);

    int curX = GAP;
    int curY = GAP;

    // First line: RISK label
    int riskX = curX + BUTTON_WIDTH + GAP;
    if(!CreateLabelEx(m_risk_label, riskX + GAP, curY, LABEL_HEIGHT, "Risk", "Risk in %:", clrBlack))
        return false;

    // Second line: BUY btn, RISK edit, SELL btn
    curY += LABEL_HEIGHT + GAP;
    if(!CreateButton(m_buy_btn, "Buy", curX, curY, BUTTON_WIDTH, BUTTON_HEIGHT, clrGreen))
        return false;

    if(!CreateEdit(m_risk_edit, "RiskEdit", riskX, curY, EDIT_WIDTH, EDIT_HEIGHT))
        return false;
    m_risk_edit.Text("10");

    int sellBtnX = riskX + EDIT_WIDTH + GAP;
    if(!CreateButton(m_sell_btn, "Sell", sellBtnX, curY, BUTTON_WIDTH, BUTTON_HEIGHT, clrRed))
        return false;

    // Third line: TP and SL labels
    curY += BUTTON_HEIGHT + 2 * GAP;
    if(!CreateLabelEx(m_tp_label, curX + GAP, curY, LABEL_HEIGHT, "TP", "TP In Points: ", clrBlack))
        return false;

    if(!CreateLabelEx(m_sl_label, sellBtnX + GAP, curY, LABEL_HEIGHT, "SL", "SL In Points: ", clrBlack))
        return false;

    // Fourth line: TP edit & SL edit
    curY += BUTTON_HEIGHT;
    if(!CreateEdit(m_tp_edit, "TPEdit", curX + GAP, curY, EDIT_WIDTH, EDIT_HEIGHT))
        return false;
    m_tp_edit.Text("100");

    if(!CreateEdit(m_sl_edit, "SLEdit", sellBtnX + GAP, curY, EDIT_WIDTH, EDIT_HEIGHT))
        return false;
    m_sl_edit.Text("100");

    // Fith line: CLOSE all positions btn
    curY += LABEL_HEIGHT + EDIT_HEIGHT;
    if(!CreateButton(m_close_all_btn, "Close All Positions", curX, curY, BUTTON_WIDTH*2+EDIT_WIDTH+GAP*2, BUTTON_HEIGHT, clrCoral))
        return false;

    return(true);
}

//+------------------------------------------------------------------+
//| On Click BTN Buy                                                 |
//+------------------------------------------------------------------+
void CTradePanel::OnClickBuy() {
    GetEditValues();

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    double stoploss = NormalizeDouble(ask - sl_pts * _Point, 5);
    double takeprofit = NormalizeDouble(ask + tp_pts * _Point, 5);

    double volume = CalculVolume(sl_pts);

    if(stoploss == 0 && takeprofit == 0)
        m_trade.Buy(volume, _Symbol, ask);
    else
        m_trade.Buy(volume, _Symbol, ask, stoploss, takeprofit);
}

//+------------------------------------------------------------------+
//| On Click BTN Sell                                                |
//+------------------------------------------------------------------+
void CTradePanel::OnClickSell() {
    GetEditValues();

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double stoploss = NormalizeDouble(bid + sl_pts * _Point, 5);
    double takeprofit = NormalizeDouble(bid - tp_pts * _Point, 5);

    double volume = CalculVolume(sl_pts);

    if(stoploss == 0 && takeprofit == 0)
        m_trade.Sell(volume, _Symbol, bid);
    else
        m_trade.Sell(volume, _Symbol, bid, stoploss, takeprofit);
}

//+------------------------------------------------------------------+
//| Get Fileds Values                                                |
//+------------------------------------------------------------------+
void CTradePanel::GetEditValues() {
    tp_pts = StringToDouble(m_tp_edit.Text());
    sl_pts = StringToDouble(m_sl_edit.Text());
    risk = StringToDouble(m_risk_edit.Text());
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CTradePanel::OnClickCloseAll() {
    CPositionInfo m_position;

    for(int i = PositionsTotal()-1; i >= 0; i--) {
        if(m_position.SelectByIndex(i)) {
            if(m_position.Symbol() == _Symbol) {
                ulong ticket = m_position.Ticket();
                if(ticket) m_trade.PositionClose(ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Event handler                                                    |
//+------------------------------------------------------------------+
bool CTradePanel::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == m_buy_btn.Name()) {
            OnClickBuy();
            return true;
        } else if(sparam == m_sell_btn.Name()) {
            OnClickSell();
            return true;
        } else if(sparam == m_close_all_btn.Name()) {
            OnClickCloseAll();
            return true;
        }
    }

    // Allow base class to process all other events
    return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Calcul volume                                                    |
//+------------------------------------------------------------------+
double CTradePanel::CalculVolume(double number_points) {
    double risk_money = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) / 100 * risk, 2);
    double pointSize  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // One lot is always 100.000 in the account currency
    double pointPricePerLot = 100000 * pointSize;

    double lot = pointPricePerLot * (risk_money / number_points);

    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double adjusted = MathFloor(lot / step) * step;

    return NormalizeDouble(adjusted, (int)MathLog10(1.0 / step));
}

//+------------------------------------------------------------------+

CTradePanel TradeFast;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    if(!TradeFast.Create(0, "Trade Fast", 0, 20, 20, PANEL_WIDTH, PANEL_HEIGHT))
        return(INIT_FAILED);

    TradeFast.Run();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    TradeFast.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert chart event function                                      |
//+------------------------------------------------------------------+
void OnChartEvent(
    const int id,
    const long& lparam,
    const double& dparam,
    const string& sparam
) {
    TradeFast.OnEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
