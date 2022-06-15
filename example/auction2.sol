pragma solitidy > 0.4.23 < 0.5.0;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }

    address public beneficiary;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint public highestBid;

    // 可以取回之前的出价
    mapping(address => uint) pendingReturns;
    event AuctionEnded(address winner, uint highestBid);

    /// 使用 modifier 可以更便捷的校验函数的入参。
    /// `onlyBefore` 会被用于后面的 `bid` 函数：
    /// 新的函数体是由 modifier 本身的函数体，并用原函数体替换 `_;` 语句来组成的。
    modifier onlyBefore(uint _time) {require(now < _time); _;}
    modifier onlyAfter(uint _time) {require(now > _time); _;}

    constructor(uint _biddingTime, uint _revealTime, address _beneficiary) public {
        beneficiary = _beneficiary;
        biddingEnd = now + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

    function bid(bytes32 _blindedBid) public payable onlyBefore(biddingEnd) {
        bids[msg.sender].push(Bid({blindedBid: _blindedBid, deposit: msg.value}));
    }

    /// 披露你的秘密竞拍价
    function reveal(uint[] _values, bool[] _fake, bytes32[] _secret)
    public onlyAfter(biddingEnd) onlyBefore(revealEnd) {
        uint length = bids[msg.sender].length;
        require(_values.length == length);
        require(_fake.length == length);
        require(_secret.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            Bid storage bid = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) = (_values[i], _fake[i], secret[i]);
            if (bid.blindedBid != keccak256(value, fake, secret)) {
                continue;
            }

            refund += bid.deposit;
            if (!fake && bid.deposit >= value) {
                if (placeBid(msg.sender, value))
                    refund -= value;
            }

            bid.blindedBid = bytes32(0);
        }
        msg.sender.transfer(refund);
    }

    function placeBid(address bidder, uint value) internal returns (bool success) {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = bidder;
        highestBid = value;
        return true;
    }

    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            msg.sender.transfer(amount);
        }
    }

    function auctionEnd() public onlyAfter(revealEnd){
        require(!ended);
        ended = true;
        beneficiary.transfer(highestBid);
        emit AuctionEnded(highestBidder, highestBid);
    }
}