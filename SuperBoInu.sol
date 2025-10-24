// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract SuperBoInu is ERC20, Ownable, Pausable {

    uint256 public taxRate; // z. B. 2 = 2 %
    address public taxWallet;
    mapping(address => bool) public isFeeExempt;

    event TaxRateUpdated(uint256 newTaxRate);
    event TaxWalletUpdated(address indexed newTaxWallet);
    event ExemptStatusUpdated(address indexed account, bool isExempt);

    constructor(
        uint256 initialSupply,
        address _taxWallet,
        uint256 _taxRate
    ) ERC20("SuperBoInu", "SBI") Ownable(msg.sender) {
        require(_taxWallet != address(0), "Invalid tax wallet");
        require(_taxRate <= 100, "Tax must be 0-100");

        taxWallet = _taxWallet;
        taxRate = _taxRate;

        _mint(msg.sender, initialSupply);
    }

    function setTaxRate(uint256 _taxRate) external onlyOwner {
        require(_taxRate <= 100, "Tax must be 0-100");
        taxRate = _taxRate;
        emit TaxRateUpdated(_taxRate);
    }

    function setTaxWallet(address _taxWallet) external onlyOwner {
        require(_taxWallet != address(0), "Invalid tax wallet");
        taxWallet = _taxWallet;
        emit TaxWalletUpdated(_taxWallet);
    }

    function setFeeExempt(address account, bool exempt) external onlyOwner {
        isFeeExempt[account] = exempt;
        emit ExemptStatusUpdated(account, exempt);
    }

    // Neue Hook-Funktion für OpenZeppelin v5.x
    function _update(address from, address to, uint256 value) internal override {
        // Bei Minting oder Burning kein Tax
        if (from == address(0) || to == address(0) || isFeeExempt[from] || isFeeExempt[to]) {
            super._update(from, to, value);
            return;
        }

        uint256 taxAmount = (value * taxRate) / 100;
        uint256 sendAmount = value - taxAmount;

        if (taxAmount > 0) {
            super._update(from, taxWallet, taxAmount);
        }

        super._update(from, to, sendAmount);
    }

    // Optional: Berechnung vorab ansehen
    function viewTax(uint256 amount) external view returns (uint256 taxAmount, uint256 sendAmount) {
        taxAmount = (amount * taxRate) / 100;
        sendAmount = amount - taxAmount;
    }
}
