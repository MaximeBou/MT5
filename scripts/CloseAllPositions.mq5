//+------------------------------------------------------------------+
//|                                            CloseAllPositions.mq5 |
//|                               Copyright 2025, Maxime Bourdouxhe. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Maxime Bourdouxhe."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <ErrorDescription.mqh>

int MaxRetries     = 10;        // Retry attempts on close failure
int RetryDelayMs   = 500;       // Delay between retries in milliseconds

void OnStart() {
    CloseAllPositions();
}

void CloseAllPositions() {
    CPositionInfo pos;
    CTrade trade;
    trade.SetDeviationInPoints(10);

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(pos.SelectByIndex(i)) {
            if(pos.Symbol() == _Symbol) {
                ulong ticket = pos.Ticket();
                int attempt = 0;
                bool closed = false;

                while(attempt < MaxRetries && !closed) {
                    if(trade.PositionClose(ticket)) {
                        PrintFormat("✅ Position ticket %I64u closed successfully", ticket);
                        closed = true;
                    } else {
                        int err = GetLastError();
                        PrintFormat(
                            "❌ Failed to close position ticket %I64u (Error %d: %s). Retry %d/%d",
                            ticket, err, ErrorDescription(err), attempt + 1, MaxRetries
                        );
                        Sleep(RetryDelayMs);
                    }
                    attempt++;
                }

                if(!closed) {
                    PrintFormat("⚠️ Gave up closing ticket %I64u after %d attempts.", ticket, MaxRetries);
                }
            }
        }
    }
}

