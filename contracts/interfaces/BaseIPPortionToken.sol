// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./IRoyaltyPortionToken.sol";

interface ITokenDistro {
    function associateTokenToWallet(address _token, address _wallet) external;
}

contract BaseIPPortionToken is ERC20, IRoyaltyPortionToken {
    event IPBinding(address ledger, address token, address song, uint256 amount, string kind);
    event HolderAdded(address holder, uint256 amount);

    bool initialized;
    string private __name;
    string private __symbol;
    string public override kind;
    address public override parentIP;
    address public override ledger;
    address public tokenDistro;

    Balance[] public holders;
    mapping(address => uint256) addressLocation;

    function initialize(
        address _ledger,
        address _rootIP,
        address _tokenDistro,
        string memory _kind,
        string memory _name,
        string memory _symbol
    ) public {
        require(!initialized, "contract is initialized!");
        initialized = true;
        tokenDistro = _tokenDistro;
        parentIP = _rootIP;
        ledger = _ledger;
        kind = _kind;
        __name = _name;
        __symbol = _symbol;
        _mint(_tokenDistro, 100 * 10 ** 18);
    }

    constructor(
        address _ledger,
        address _rootIP,
        address _initialHolder,
        string memory _kind,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        initialize(_ledger, _rootIP, _initialHolder, _kind, _name, _symbol);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return __name;
    }

    // /**
    //  * @dev See {IERC721Metadata-symbol}.
    //  */
    function symbol() public view override returns (string memory) {
        return __symbol;
    }

    function updateBalances(address _walletHolder) private {
        if (_walletHolder == address(0)) {
            return;
        }
        uint256 foundIndex = addressLocation[address(_walletHolder)];
        uint256 holdersLength = holders.length;
        if ((foundIndex == 0 && holdersLength == 0) || (foundIndex == 0 && holders[0].holder != _walletHolder)) {
            uint256 balance = balanceOf(_walletHolder);

            // holders.push(Balance(_address,balance));
            Balance memory holder;
            holder.holder = _walletHolder;
            holder.amount = balance;
            holders.push(holder);

            addressLocation[_walletHolder] = holders.length - 1;
            ITokenDistro(tokenDistro).associateTokenToWallet(address(this), _walletHolder);
            emit HolderAdded(_walletHolder, balance);
        } else {
            holders[addressLocation[_walletHolder]].amount = balanceOf(_walletHolder);
        }
    }

    //   function _afterTokenTransfer(
    //         address from,
    //         address to,
    //         uint256 amount
    //     ) internal virtual {
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        super._transfer(from, to, amount);
        updateBalances(from);
        updateBalances(to);
    }

    function max() public pure override returns (uint256) {
        return 100;
    }

    function getHolders() public view override returns (Balance[] memory) {
        return holders;
    }

    function bindToSong(address _song) public {
        require(_msgSender() == ledger, "only ledger allowed to bind");
        require(parentIP == address(0), "already bound to song");
        require(_song != address(0), "invalid song");
        parentIP = _song;
        emit IPBinding(ledger, address(this), parentIP, balanceOf(ledger), kind);
    }
}
