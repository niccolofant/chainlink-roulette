// SPDX-License-Identifier: minutes
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Roulette is VRFConsumerBase, Ownable {
    uint256 public MAX_BET_RATIO = 1000;
    uint256 public MAX_BET = 1 * 10**18;

    bytes32 internal keyHash;
    uint256 internal fee;

    struct Bet {
        uint256 betNum;
        uint256 betAmount;
        address payable bettor;
    }

    mapping(bytes32 => Bet) public bookOfBets;

    uint256 internal randomResult;
    uint256 public spinResult;

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Rinkeby
     * Chainlink VRF Coordinator address: 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
     * LINK token address:                0x01BE23585060835E02B77ef475b0Cc51aA1e0709
     * Key Hash: 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
     */
    constructor()
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator address
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // LINK Token address
        )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10**18; // 0.1 LINK
    }

    modifier checkMaxBet() {
        require(
            msg.value <= MAX_BET,
            "Roulette: This bet exceed max possible bet"
        );
        _;
    }

    function modifyMaxBet() internal {
        MAX_BET = address(this).balance / MAX_BET_RATIO;
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawBalance(uint256 amount, address payable to)
        external
        onlyOwner
    {
        to.transfer(amount);
        modifyMaxBet();
    }

    function spinWheel(uint256 betNum) external payable checkMaxBet {
        // Get address of sender
        address payable bettor;
        bettor = payable(msg.sender);

        //Request randomness, get request id
        bytes32 requestId = getRandomNumber();

        //store request id and address
        Bet memory curBet = Bet(betNum, msg.value, bettor);
        bookOfBets[requestId] = curBet;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() private returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        randomResult = randomness;

        //load bet from memory
        Bet memory _curBet = bookOfBets[requestId];
        uint256 _betNum = _curBet.betNum;
        address payable _bettor = _curBet.bettor;
        uint256 _amount = _curBet.betAmount;

        //calculate spin result
        uint256 _spinResult = randomResult % 33;

        //display spin result to public (only works if low volume)
        spinResult = _spinResult;

        //pay if they are a winner
        if (_spinResult == _betNum) {
            (bool sent, ) = _bettor.call{value: _amount * 32}("");
            require(sent, "failed to send ether :(");
        }
        modifyMaxBet();

        //delete bet from memory

        delete bookOfBets[requestId];
    }
}
