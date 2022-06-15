pragma solidity ^0.4.22;

contract SimpleAuction {
    // 拍卖参数
    address public beneficiary;

    // 拍卖结束时间的时间戳
    uint public auctionEnd;

    // 拍卖当前状态
    address public highestBidder;
    uint public highestBid;

    // 取回之前的出价
    mapping(address => uint) pendingReturns;

    // 拍卖结束，true后禁止变更
    bool ended;

    // 变更触发的事件
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    // 以下是所谓的 natspec 注释，可以通过三个斜杠来识别
    // 当用户被要求确认交易时将显示

    /// 以受益者地址 `_beneficiary` 的名义，
    /// 创建一个简单的拍卖，拍卖时间为 `_biddingTime` 秒。
    constructor(uint _biddingTime, address _beneficiary) public {
        beneficiary = _beneficiary;
        auctionEnd = now + _biddingTime;
    }

    /// 对拍卖进行出价，具体的出价随交易一起发送
    /// 如果没有在拍卖中胜出，则返还出价。
    function bid() public payable {
        // 参数不是必要的。因为所有的信息已经包含在了交易中。
        // 对于能接收的以太币的函数，关键字 payable 是必须的。

        // 如果拍卖已经结束，撤销函数的调用
        require (
            now <= auctionEnd,
            "Auction already ended."
        );

        // 如果出价不够高，返还你的钱
        require (
            msg.Value > highestBid,
            "There already is a higher bid."
        );

        if (highestBid != 0) {
            // 返还出价时，简单地直接调用highestBidder.send(highestBid)函数，
            // 是有安全风险的，因为它有可能执行一个非信任合约。
            // 更为安全的做法是让接收方自己提取金钱。
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// 取回出价 (当前出价已经被超越)
    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }

        return true;
    }

    /// 结束拍卖，并把最高的出价发送给受益人
    function auctionEnd() public {
        require(now >= auctionEnd, "Auction not yet ended.");
        require(!ended, "auctionEnd has already been called.");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        beneficiary.transfer(highestBid);
    }
}