// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract Token {
    // Mapping of addresses to their balances
    mapping(address => uint256) public balanceOf;
    
    // Fee percentage deducted from transaction amount (in decimals)
    uint8 public feePercentage = 5;

    // Contract deploy time for expiration validation
    uint256 public contractStartTime;
    
    // Event for transfer logging
    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        contractStartTime = block.timestamp; // Store the contract's deployment time
        balanceOf[msg.sender] += 1000 * 10**6; // Initial balance of 1000 tokens with 6 decimals
        emit Transfer(msg.sender, msg.sender, 1000 * 10**6);  // Emit event for initial supply
    }

    function transfer(address recipient, uint256 amount) public returns (bool success) {
        // Ensure the contract is still valid
        require(block.timestamp - contractStartTime <= 1 days, "Transaction expired");
        
        // Calculate fee
        uint256 fee = (amount * feePercentage) / 100;
        uint256 amountAfterFee = amount - fee;

        // Ensure sufficient balance for the transfer and fee
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        // Update balances
        balanceOf[recipient] += amountAfterFee; 
        balanceOf[msg.sender] -= amount;

        // Emit the Transfer event
        emit Transfer(msg.sender, recipient, amountAfterFee);
        
        // Transfer fee to contract owner (or another logic you prefer)
        balanceOf[msg.sender] -= fee; // Subtract the fee from the sender's balance (could be sent to owner)

        return true;
    }
}
