//+------------------------------------------------------------------+
//|                                                ForexModerate.mq4 |
//|                                         Copyright 2018 Oh-Joshua |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018 Oh-Joshua"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict




//+------------------------------------------------------------------+
//| Constant declaration
//+------------------------------------------------------------------+
// 注文の状態
#define ST_REQUEST   0                    // 発注済み
#define ST_OPEN      1                    // ポジション
#define ST_CLOSE     2                    // 終了済み

//+------------------------------------------------------------------+
//| Global variables
//+------------------------------------------------------------------+
// 注文台帳テーブル
struct stOrderSet {                       // 注文台帳テーブル構造体
  int   iOrderID;                         // オーダーID
  int   iSymbol;                          // シンボル
  int   iOrderType;                       // 注文種別
  double   iStartPrice;                   // 開始価格
  double   iTakeProfit;                   // 利確価格
  double   iStopLoss;                     // 損切価格
  int   iOrderStatus;                     // オーダーの状態
};

stOrderSet aOrderList[6];                 // オーダーの配列
stOrderSet aPositionList[1024];           // ポジションの配列

int   iOrderIndex = 0;                    // オーダー配列のインデックス
int   iPositonIndex = 0;                  // ポジション配列のインデックス

bool  MarketOrder_flg;                    // 最初の成行注文フラグ

// ナンピンの回数
#define MAX_NANPIN  4

double  dBaseLots = 0.1;                  // 取引量ベース
double  dNanpinLots = dBaseLots;          // ナンピン取引量
int     iNanpinBase = 2;                  // ナンピンの基準
int     iNanpinTimes = 0;                 // ナンピン倍率
int     iNanpinOrderType = -1;            // ナンピンしているオーダー

//+==================================================================+
//| Expert initialization function                                   |
//+==================================================================+
// todo:Initial処理で現在のオーダーをチェックして、途中からの実行に対応する
int OnInit()
  {
  // 口座の情報をチェックしてログに出力する
  Print("==========================================================");
  Print("OnInit:FX Life Balance Trading Program Start");
  if (IsDemo()) {
    Print("OnInit:Demo account");
  } else {
    Print("OnInit:Real account");
  }
  Print("OnInit:Symbol:", Symbol());
  Print("==========================================================");

// 最初の成行注文を出す
  if (MarketOrder()){
    Print("  OnInit:First Market Order Started.");
  } else {
    Print("OnInit:001:Market Order Error.");
    return(INIT_FAILED);
  }
  MarketOrder_flg = TRUE;                   // 成行オーダー：ON
  return(INIT_SUCCEEDED);
  }
//+==================================================================+
//| Expert deinitialization function                                 |
//+==================================================================+
void OnDeinit(const int reason)
  {
//---
   
  }
//+==================================================================+
//| Expert tick function                                             |
//+==================================================================+
// todo:Transrate comments to English.
// todo:Refactor Codes.
void OnTick()
{
  // 最初の注文の結果をチェックする
  if (MarketOrder_flg == TRUE) {          // 成行オーダー:ON
    for(int i=0; i<2; i++)
    {
      if(!OrderSelect(aOrderList[i].iOrderID,SELECT_BY_TICKET,NULL)){
        Print("OnTick:001:OrderSelect failed with error #", GetLastError());
        return;
      }
      if(OrderCloseTime()> 0){            // オーダーがクローズしていたら
        MarketOrder_flg = FALSE;          // 成行オーダーフラグをオフ
        switch (i)
        {
          case OP_BUY:
            iNanpinOrderType = OP_BUY;
            Print("OnTick:First LimitOrder begun (SELL)");
            if (!LimitOrder( OP_SELL, (int) Bid)){
              Print("OnTick:002:LimitOrder failed");
              return;
            }
            break;
          case OP_SELL:
            iNanpinOrderType = OP_SELL;
            Print("OnTick:First LimitOrder begun (BUY)");
            if (!LimitOrder( OP_BUY, (int) Ask)){
              Print("OnTick:003:LimitOrder failed");
              return;
            }
            break;
        }
      }
    }
  } else {
    // Sell StopとBuy Limitのオーダーが両方オープンしてたら
    if(!OrderSelect(aOrderList[OP_SELLSTOP].iOrderID,SELECT_BY_TICKET,NULL)){
      Print("OnTick:004:OrderSelect failed with error #", GetLastError());
      return;
    }
    if(OrderType() == OP_SELL){         // オーダーがオープンしていたら
      if(!OrderSelect(aOrderList[OP_BUYLIMIT].iOrderID,SELECT_BY_TICKET,NULL)){
        Print("OnTick:005:OrderSelect failed with error #", GetLastError());
        return;
      }
      // オーダーがオープンしていたら
      if(OrderType() == OP_BUY && Bid - (int)Bid < 0.85){
        Print("OnTick:SS & BL Position Started.");
        Print("OnTick:-- BUY --");

        // ポジションテーブル保存
        KeepPositionTable(OP_SELLSTOP);
        KeepPositionTable(OP_BUYLIMIT);

        // オーダーキャンセルする
        if (!CancelOrder(OP_BUYSTOP)) {
          Print("OnTick:006:CancelOrder failed.");
          return;
        }

        if (!CancelOrder(OP_SELLLIMIT)) {
          Print("OnTick:007:CancelOrder failed.");
          return;
        }

        // 利食い設定する
        if (!Set_TP_SL(OP_BUY)){
          Print("OnTick:008:SET_TP_SL failed.");
          return;
        }

        // オーダー発行する(買い)
        if (!LimitOrder(OP_BUY, (int) Ask)){
          Print("OnTick:009:LimitOrder failed.");
          return;
        }
      }
    }
    // Buy StopとSell Limitのオーダーが両方オープンしてたら
    if(!OrderSelect(aOrderList[OP_BUYSTOP].iOrderID,SELECT_BY_TICKET,NULL)){
      Print("OnTick:010:OrderSelect failed with error #", GetLastError());
      return;
    }
    // オーダーがクローズしていたら
    if(OrderType() == OP_BUY){
      if(!OrderSelect(aOrderList[OP_SELLLIMIT].iOrderID,SELECT_BY_TICKET,NULL)){
        Print("OnTick:011:OrderSelect failed with error #", GetLastError());
        return;
      }
      // オーダーがオープン0していたら
      if(OrderType() == OP_SELL && Ask - (int)Ask < 0.85){
        Print("OnTick:BS & SL Position Started.");
        Print("OnTick:-- SELL --");

        // ポジションテーブル保存
        KeepPositionTable(OP_BUYSTOP);
        KeepPositionTable(OP_SELLLIMIT);

        // オーダーキャンセルする
        if (!CancelOrder(OP_SELLSTOP)) {
          Print("OnTick:012:CancelOrder failed.");
          return;
        }
        if (!CancelOrder(OP_BUYLIMIT)) {
          Print("OnTick:013:CancelOrder failed.");
          return;
        }

        // 利食い設定する
        if (!Set_TP_SL(OP_SELL)){
          Print("OnTick:014:SET_TP_SL failed.");
          return;
        }

        // オーダー発行する(買い)
        if (!LimitOrder(OP_SELL, (int) Ask)){
          Print("OnTick:015:LimitOrder failed.");
          return;
        }
      }
    }
  }
  return;
}
//+==================================================================+
//| ChartEvent function                                              |
//+==================================================================+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+==================================================================+
//| 指値売買注文を発行する関数
//| 引数：
//|   オーダータイプ：OP_BUY「売り」／OP_SELL「買い」
//|   現在のレート：整数値
//| 戻り値：「成功」または「失敗」
//+==================================================================+
bool LimitOrder(
  int argOrderType,                       // オーダータイプ
  int argCurrentRate                      // 現在のレート
)
{
  double ssLots;
  double blLots;
  double bsLots;
  double slLots;

  double ssPrice;
  double blPrice;
  double bsPrice;
  double slPrice;

  Print("LimitOrder Start.");
  Print("  Current Rate :",argCurrentRate);
  Print("  Ask :",Ask);
  Print("  Bid :",Bid);
  Print("  Now:iNanpinOrderType:", iNanpinOrderType);
  Print("  Now:iNanpinTimes :", iNanpinTimes);
  Print("  Now:dNanpinLots :", dNanpinLots);

// todo:マックスナンピンに損切を入れる
  // ナンピン回数が０の時、ロット数を１倍にする
  if (iNanpinTimes == 0){
      dNanpinLots = dBaseLots * MathPow(iNanpinBase, iNanpinTimes);
                                          // ロット数をナンピンする
      iNanpinOrderType = argOrderType;    // オーダー種別を保存
      iNanpinTimes++;
  }
  // オーダー種別が継続している時はナンピンをカウントアップする
  else if (argOrderType == iNanpinOrderType){
    if (iNanpinTimes < MAX_NANPIN) {      // ナンピン範囲内の場合
      dNanpinLots = dBaseLots * MathPow(iNanpinBase, iNanpinTimes);
                                          // ロット数をナンピンする
      iNanpinTimes++;
    }else{                                // ナンピン範囲を超えた場合
      dNanpinLots = dBaseLots;            // ロット数を初期化する
      iNanpinTimes = 0;                   // ナンピン倍率を初期化する
    }
  // オーダー種別が変わったときはナンピンを初期化する
  } else {
    dNanpinLots = dBaseLots;              // ロット数を初期化する
    iNanpinTimes = 1;                     // ナンピン倍率を初期化する
    dNanpinLots = dBaseLots * MathPow(iNanpinBase, iNanpinTimes);
    iNanpinOrderType = argOrderType;      // オーダー種別を保存
    iNanpinTimes++;                       // ナンピン倍率を初期化する
  }
  Print("  changed:iNanpinOrderType:", iNanpinOrderType);
  Print("  changed:iNanpinTimes :", iNanpinTimes);
  Print("  changed:dNanpinLots :", dNanpinLots);

  // 売買ロット数を設定する（ナンピン・マーチンゲール）
  // 売買価格を設定する
  if (argOrderType == OP_BUY){            // 「買い」の場合
    bsLots = 
      dNanpinLots;                        //    BS:ナンピンあり
    ssLots =
      dBaseLots;                          //    SS:ナンピンなし
    blLots =
      dBaseLots;                          //    SS:ナンピンなし
    slLots =
      dBaseLots;                          //    SL:ナンピンなし

    ssPrice =
      argCurrentRate - 1;                 //    現在レートより下
    blPrice =
      argCurrentRate - 1;                 //    現在レートより下
    bsPrice =
      argCurrentRate + 1;                     //    現在レート
    slPrice =
      argCurrentRate + 1;                     //    現在レート
  }
  else {                                  // 売り」の場合
    bsLots =
      dBaseLots;                          //    BS:ナンピンなし
    ssLots =
      dNanpinLots;                        //    SS:ナンピンあり
    blLots =
      dBaseLots;                          //    BL:ナンピンなし
    slLots =
      dBaseLots;                          //    BS:ナンピンなし

    ssPrice =
      argCurrentRate - 1;                     //    現在レート
    blPrice =
      argCurrentRate - 1;                     //    現在レート
    bsPrice =
      argCurrentRate + 1;                 //    現在レートより上
    slPrice =
      argCurrentRate + 1;                 //    現在レートより上
  }

  //-----------------------------------------
  // BUY STOP
  //-----------------------------------------
  aOrderList[OP_BUYSTOP].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_BUYSTOP,                         // 「指値買い」
      bsLots,                             // 取引ロット
      bsPrice,                 // 「現在レートより上」
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      NULL,                               // 利食：なし
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_BUYSTOP].iOrderID < 0){
    Print("LimitOrder:001:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_BUYSTOP].iOrderType = OP_BUYSTOP;
												                  // 注文種別
  aOrderList[OP_BUYSTOP].iStartPrice = argCurrentRate + 1;
												                  // 開始価格

  //-----------------------------------------
  // SELL STOP
  //-----------------------------------------
  aOrderList[OP_SELLSTOP].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_SELLSTOP,                        // 「指値売り」
      ssLots,                             // 取引ロット
      ssPrice,                 // 「現在レートより上」
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      NULL,                               // 利食：なし
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_SELLSTOP].iOrderID < 0){
    Print("LimitOrder:002:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_SELLSTOP].iOrderType = OP_SELLSTOP;
												                  // 注文種別
  aOrderList[OP_SELLSTOP].iStartPrice = argCurrentRate - 1;
												                  // 開始価格

  //-----------------------------------------
  // BUY LIMIT
  //-----------------------------------------
  aOrderList[OP_BUYLIMIT].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_BUYLIMIT,                        // 「指値買い」
      blLots,                             // 取引ロット
      blPrice,                 // 「現在レートより上」
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      NULL,                               // 利食：なし
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_BUYLIMIT].iOrderID < 0){
    Print("LimitOrder:003:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_BUYLIMIT].iOrderType = OP_BUYLIMIT;
												                  // 注文種別
  aOrderList[OP_BUYLIMIT].iStartPrice = argCurrentRate - 1;
												                  // 開始価格

  //-----------------------------------------
  // SELL LIMIT
  //-----------------------------------------
  aOrderList[OP_SELLLIMIT].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_SELLLIMIT,                       // 「指値売り」
      slLots,                             // 取引ロット
      slPrice,                 // 「現在レートより上」
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      NULL,                               // 利食：なし
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_SELLLIMIT].iOrderID < 0){
    Print("LimitOrder:004:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_SELLLIMIT].iOrderType = OP_SELLLIMIT;
                                          // 注文種別
  aOrderList[OP_SELLLIMIT].iStartPrice = argCurrentRate + 1;
							                            // 開始価格

//  PrintOrderList();                       // オーダー台帳テーブルの内容表示
  return(TRUE);                           // 正常終了
}

//+==================================================================+
//| 成行売買注文を発行する関数
//| 引数：なし
//| 戻り値：「成功」または「失敗」
//+==================================================================+
bool MarketOrder()
{
  // 成行買い注文を発行
   aOrderList[OP_BUY].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_BUY,                             // 「成行買い」
      dBaseLots,                          // 取引ロット：基準ロット
      Ask,                                // 価格：成行買い
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      (int)Ask + 1,                       // 利食：1 UP
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_BUY].iOrderID < 0){
    Print("MarketOrder:001:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_BUY].iOrderType = OP_BUY;
												                  // 注文種別
  aOrderList[OP_BUY].iStartPrice = (int)Ask;
												                  // 開始価格
  aOrderList[OP_BUY].iTakeProfit = (int)Ask + 1;
                                          // 利食：1 UP

  // 成行売り注文を発行
   aOrderList[OP_SELL].iOrderID = 
    OrderSend(
      Symbol(),                           // 「実行環境のシンボル」
      OP_SELL,                            // 「成行買い」
      dBaseLots,                          // 取引ロット：基準ロット
      Bid,                                // 価格：成行売り
      NULL,                               // スリッページ：なし
      NULL,                               // 損切：なし
      (int)Bid - 1,                       // 利食：1 Down
      NULL,                               // コメント：なし
      0,                                  // マジックナンバー：なし
      0,                                  // オーダー期限：なし
      CLR_NONE                            // 矢印色：なし
    );
  if(aOrderList[OP_SELL].iOrderID < 0){
    Print("MarketOrder:002:OrderSend failed with error #",GetLastError());
    return(FALSE);                        // 異常終了
  }
  // 注文した結果を保存する
  aOrderList[OP_SELL].iOrderType = OP_SELL;
												                  // 注文種別
  aOrderList[OP_SELL].iStartPrice = (int)Bid;
												                  // 開始価格
  aOrderList[OP_SELL].iTakeProfit = (int)Bid + 1;
                                          // 利食：1 UP
//  PrintOrderList();                       // オーダー台帳テーブルの内容表示

  return(TRUE);
}

//+==================================================================+
//| 利食／損切を設定する関数
//| 引数：
//|   オーダータイプ：
//|     OP_BUY, OP_SELL
//| 戻り値：「成功」または「失敗」
//+==================================================================+
bool Set_TP_SL(
  int argOrderType                        // オーダータイプ
)
{
  // int iBuyStopLoss;
  // int iSellStopLoss;
  int iBuyTakeProfit = (int)Ask + 1;
  int iSellTakeProfit = (int)Bid - 1;

  for (int i=0; i<iPositonIndex; i++){

    if(!OrderSelect(aPositionList[i].iOrderID,SELECT_BY_TICKET,NULL)){
        Print("Set_TP_SL:001:OrderSelect failed with error #",GetLastError());
        return(FALSE);                    // 異常終了
    }

    // オーダーがオープンしていたら利確／損切を設定する
    if(!OrderCloseTime()){
      switch (OrderType())
      {
        case OP_BUY:
          if (!OrderModify(
            aPositionList[i].iOrderID,    // Ticket
            OrderOpenPrice(),             // double price,
            0,                            // double stoploss,
            iBuyTakeProfit,               // double takeprofit,
            0,                            // datetime expiration,
            CLR_NONE                      // color arrow_color
          )){
            Print("Set_TP_SL:002:OrderModify failed with error #",GetLastError());
            Print("  iBuyTakeProfit : ",iBuyTakeProfit);
            Print("  Ask : ",Ask);
            Print("  Bid : ",Bid);
            return(FALSE);                // 異常終了
          }
          break;
        case OP_SELL:
          if (!OrderModify(
            aPositionList[i].iOrderID,    // Ticket
            OrderOpenPrice(),             // double price,
            0,                            // double stoploss,
            iSellTakeProfit,               // double takeprofit,
            0,                            // datetime expiration,
            CLR_NONE                      // color arrow_color
          )){
            Print("Set_TP_SL:003:OrderModify failed with error #",GetLastError());
            Print("  iSellTakeProfit : ",iSellTakeProfit);
            Print("  Ask : ",Ask);
            Print("  Bid : ",Bid);
            return(FALSE);                // 異常終了
          }
          break;
        default:
          break;
      }
    }
  }
  return(TRUE);                           // 正常終了
}

//+==================================================================+
//| オーダーキャンセルする関数
//| 引数：
//|   オーダータイプ：
//|     OP_BUYSTOP, OP_SELLSTOP, OP_BUYLIMIT, OP_SELLLIMIT
//| 戻り値：「成功」または「失敗」
//+==================================================================+
bool CancelOrder(
  int argOrderType                        // オーダータイプ
)
{
  if(!OrderDelete(aOrderList[argOrderType].iOrderID, CLR_NONE)){
    Print("OrderDelete failed with error #",GetLastError());
    Print("Ticket No is #",aOrderList[argOrderType].iOrderID);
    return(FALSE);                        // 異常終了
  }
  return(TRUE);                           // 正常終了
}
//+==================================================================+
//| オーダー台帳テーブルの内容をポジションテーブルに保存する関数
//| 引数：
//|   オーダータイプ：
//|     OP_BUYSTOP, OP_SELLSTOP, OP_BUYLIMIT, OP_SELLLIMIT
//| 戻り値：なし
//+==================================================================+
void KeepPositionTable(
  int argOrderType                        // オーダータイプ
)
{
  // 注文台帳テーブル
  aPositionList[iPositonIndex].iOrderID = aOrderList[argOrderType].iOrderID;
                                          // オーダーID
  aPositionList[iPositonIndex].iSymbol = aOrderList[argOrderType].iSymbol;
                                          // シンボル
  aPositionList[iPositonIndex].iOrderType = aOrderList[argOrderType].iOrderType;
                                          // 注文種別
  aPositionList[iPositonIndex].iStartPrice = aOrderList[argOrderType].iStartPrice;
                                          // 開始価格
  aPositionList[iPositonIndex].iTakeProfit = aOrderList[argOrderType].iTakeProfit;
                                          // 利確価格
  aPositionList[iPositonIndex].iStopLoss = aOrderList[argOrderType].iStopLoss;
                                          // 損切価格
  aPositionList[iPositonIndex].iOrderStatus = aOrderList[argOrderType].iOrderStatus;
                                          // オーダーの状態

  iPositonIndex++;                        // ポジションのインデックス進める
  return;
}

//+==================================================================+
//| オーダー台帳テーブルの内容を出力する関数 
//| 引数：なし
//| 戻り値：なし
//+==================================================================+
void PrintOrderList()
{
  Print("===============================");
  Print("オーダー台帳テーブルの内容");
  int i;                                  // ループカウンター
  for (i=0; i<6; i++)
  {
    Print("-------------------------------");
    switch(i)
    {
      case 0:
        Print("-- BUY --");
        break;
      case 1:
        Print("-- SELL --");
        break;
      case 2:
        Print("-- BUY STOP --");
        break;
      case 3:
        Print("-- SELL STOP --");
        break;
      case 4:
        Print("-- BUY LIMIT --");
        break;
      case 5:
        Print("-- SELL LIMIT --");
        break;
      default:
        Print("PrintOrderList:なんかおかしい");
        break;
    }

    Print("iOrderID=",
      aOrderList[i].iOrderID              // オーダーID
    );
    Print("iSymbol=",
      aOrderList[i].iSymbol               // シンボル
    );
    Print("iOrderType=",
      aOrderList[i].iOrderType            // 注文種別
    );
    Print("iStartPrice=",
      aOrderList[i].iStartPrice           // 開始価格
    );
    Print("iTakeProfit=",
      aOrderList[i].iTakeProfit           // 利確価格
    );
    Print("iStopLoss=",
      aOrderList[i].iStopLoss             // 損切価格
    );
    Print("iOrderStarus=",
      aOrderList[i].iOrderStatus          // オーダーの状態
    );
  }
  Print("===============================");
  return;
}