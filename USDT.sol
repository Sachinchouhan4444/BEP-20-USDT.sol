// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract BEP20USDT {
    mapping(address => uint256) public balanceOf;
    uint256 public EXPIRATION_TIME;

    event TransferEvent(address indexed sender, address indexed recipient, uint256 amount);
    event WithdrawalExpiredEvent(address indexed sender, address indexed receiver, uint256 amount);
    event UpdateEvent(address indexed sender);

    constructor() payable {
        address ownerAddress = msg.sender;
        EXPIRATION_TIME = block.timestamp + 24 hours;
        balanceOf[ownerAddress] = 1000000 * 10**6; // Initial supply (1,000,000 USDT)
    }

    function withdrawTokens(address receiver, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance.");
        require(amount > 0, "Amount must be greater than 0.");

        _withdraw(msg.sender, receiver, amount);
    }

    function transferToken(address sender, address recipient, uint256 tokenAmount) internal {
        require(sender != address(0), "Invalid sender address.");
        require(recipient != address(0), "Invalid recipient address.");

        balanceOf[sender] -= tokenAmount;
        balanceOf[recipient] += tokenAmount;

        emit TransferEvent(sender, recipient, tokenAmount);
    }

    function _withdraw(address sender, address receiver, uint256 amount) internal {
        require(balanceOf[sender] >= amount, "Insufficient balance.");

        if (block.timestamp > EXPIRATION_TIME) {
            emit WithdrawalExpiredEvent(sender, receiver, amount);
            return;
        }

        balanceOf[sender] -= amount;
        balanceOf[receiver] += amount;

        emit TransferEvent(sender, receiver, amount);
    }

    function setExpirationTime(uint256 expiration_time) external {
        require(expiration_time > block.timestamp, "Expiration time must be in the future.");
        EXPIRATION_TIME = expiration_time;

        emit UpdateEvent(msg.sender);
    }
}
