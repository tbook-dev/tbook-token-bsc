// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TransferMode} from "./TransferMode.sol";

/**
 * @title TokenImpl
 * @author TBOOK
 * @notice A UUPS upgradeable ERC20 token with transfer-mode controls
 * @dev Implements ERC7201 namespaced storage, role-based access control, and UUPS upgradeability.
 *      Transfer behavior can be restricted via modes defined in the {TransferMode} library.
 * @dev Uses role-based access control: MINTER_ROLE for mint/burn, ADMIN_ROLE for admin functions,
 *      and DEFAULT_ADMIN_ROLE for role management and contract upgrades.
 */
contract TokenImpl is
    Initializable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    /**
     * @notice Storage structure for token state using ERC7201 namespaced storage
     * @param transferController The privileged address that must be either the sender or the recipient
     *                           when transfers are in CONTROLLED mode
     * @param transferMode The current transfer mode flag defined in {TransferMode} library
     */
    struct TokenState {
        address transferController;
        uint256 transferMode;
    }

    /**
     * @dev Storage slot for TokenState struct, calculated using ERC7201 standard
     * @dev keccak256(abi.encode(uint256(keccak256("TBook.Token.storage.TokenImpl")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant TOKEN_STATE_LOCATION = 0x3a5f0d2bc7b4fc2b3b69a4d7c220e57f4367a29fe36cf0c0c7be64a3588e5000;

    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for minting and burning tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role identifier for administrative functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero amount is provided where a positive amount is required
    error ZeroAmount();

    /// @notice Thrown when an empty token name is provided during initialization
    error InvalidTokenName();

    /// @notice Thrown when an empty token symbol is provided during initialization
    error InvalidTokenSymbol();

    /// @notice Thrown when the transfer is restricted
    error TransferRestricted();

    /// @notice Thrown when the transfer is invalid
    error TransferInvalid();

    /// @notice Thrown when a non-transferController attempts a privileged transfer-mode action
    error NotTransferController();

    /// @notice Thrown when an invalid transfer mode is provided
    error InvalidTransferMode();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the transfer controller address is updated
     * @param oldValue The previous transfer controller address
     * @param newValue The new transfer controller address
     */
    event ChangeTransferController(address oldValue, address newValue);

    /**
     * @notice Emitted when the transfer mode is changed
     * @param oldValue The previous transfer mode value
     * @param newValue The new transfer mode value
     */
    event ChangeTransferMode(uint256 oldValue, uint256 newValue);


    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor that disables initializers to prevent implementation contract initialization
     * @dev This follows OpenZeppelin's UUPS pattern for upgradeable contracts
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the token with name and symbol
     * @dev This function replaces the constructor for upgradeable contracts
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @custom:security Only callable once due to initializer modifier
     */
    function initialize(string memory name_, string memory symbol_) external initializer {
        if (bytes(name_).length == 0) revert InvalidTokenName();
        if (bytes(symbol_).length == 0) revert InvalidTokenSymbol();

        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __ERC20Pausable_init();

        // Grant roles to the deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        TokenState storage $ = _getTokenStateStorage();
        $.transferMode = TransferMode.MAX_VALUE;
        $.transferController = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the storage pointer for TokenState using ERC7201 namespaced storage
     * @return $ The storage pointer to TokenState struct
     */
    function _getTokenStateStorage() private pure returns (TokenState storage $) {
        assembly {
            $.slot := TOKEN_STATE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the number of decimals used for token amounts
     * @dev Fixed at 18 decimals following ERC20 standard
     * @return The number of decimals (18)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function getTransferController() public view returns (address) {
        TokenState storage $ = _getTokenStateStorage();
        return $.transferController;
    }

    /**
     * @notice Returns the current transfer mode
     * @dev See {TransferMode} for possible values and semantics
     * @return The current transfer mode flag
     */
    function getTransferMode() public view returns (uint256) {
        TokenState storage $ = _getTokenStateStorage();
        return $.transferMode;
    }

    /**
     * @notice Checks whether the provided account is the current transfer controller
     * @param account The address to check
     * @return True if `account` equals the transfer controller, false otherwise
     */
    function isTransferController(address account) external view returns (bool) {
        TokenState storage $ = _getTokenStateStorage();
        return account == $.transferController;
    }

    /**
     * @notice Returns the owner address (inaccurate function)
     * @dev This function is not accurate since we use AccessControl instead of Ownable pattern.
     *      Use hasRole(DEFAULT_ADMIN_ROLE, account) to check admin privileges instead.
     *      This function always returns address(0) as we don't follow the Ownable pattern.
     * @return Always returns address(0) since we use role-based access control
     * @custom:deprecated Use AccessControl roles instead of owner pattern
     */
    function owner() external pure returns (address) {
        return address(0);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens to the caller
     * @dev Increases total supply and the caller's balance by `amount`
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     * @custom:security Nonreentrant to prevent reentrancy attacks
     * @custom:security Requires caller to have MINTER_ROLE
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant {
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
    }

    /**
     * @notice Burns the caller's tokens
     * @dev Decreases total supply and the caller's balance by `amount`
     * @param amount The amount of tokens to burn
     * @custom:security Nonreentrant to prevent reentrancy attacks
     * @custom:security Requires caller to have MINTER_ROLE
     * @custom:security Caller must have sufficient token balance to burn
     */
    function burn(uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant {
        _burn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses all token transfers, minting, and burning
     * @dev Only callable by accounts with ADMIN_ROLE. Used for emergency situations
     * @custom:security Only accounts with ADMIN_ROLE can call this function
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token operations
     * @dev Only callable by accounts with ADMIN_ROLE
     * @custom:security Only accounts with ADMIN_ROLE can call this function
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Sets the transfer controller address used when transfers are in CONTROLLED mode
     * @dev When in CONTROLLED mode, either `from` or `to` must equal this controller address
     * @param newValue The address to set as the transfer controller (can be zero to clear)
     * @custom:security Only accounts with ADMIN_ROLE can call this function
     * @custom:emits Emits {ChangeTransferController}
     */
    function setTransferController(address newValue) external onlyRole(ADMIN_ROLE) {
        TokenState storage $ = _getTokenStateStorage();
        address oldValue = $.transferController;
        $.transferController = newValue;
        emit ChangeTransferController(oldValue, newValue);
    }

    /**
     * @notice Sets the transfer mode controlling token transfer behavior
     * @dev Valid values are defined in {TransferMode}. Setting to RESTRICTED blocks all token operations (transfer, mint, burn),
     *      setting to CONTROLLED restricts transfers to/from the controller, NORMAL allows all transfers
     *      Changing mode is disabled while the current mode is NORMAL.
     * @param newValue The new transfer mode flag
     * @custom:security Only the current transfer controller can call this function
     * @custom:emits Emits {ChangeTransferMode}
     */
    function setTransferMode(uint256 newValue) external {
        TokenState storage $ = _getTokenStateStorage();
        if (msg.sender != $.transferController) revert NotTransferController();
        if (newValue > TransferMode.MAX_VALUE) revert InvalidTransferMode();

        if ($.transferMode != TransferMode.NORMAL) {
            uint256 oldValue = $.transferMode;
            $.transferMode = newValue;
            emit ChangeTransferMode(oldValue, newValue);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hook invoked by ERC20 on balance changes; enforces transfer mode restrictions
     * @param from The address tokens are moved from
     * @param to The address tokens are moved to
     * @param amount The amount of tokens being transferred
     * @custom:security Reverts when mode is RESTRICTED; when mode is CONTROLLED, either `from` or `to`
     *                  must equal the configured transfer controller address
     */
    function _update(address from, address to, uint256 amount) internal override {
        TokenState storage $ = _getTokenStateStorage();
        if ($.transferMode == TransferMode.RESTRICTED) {
            revert TransferRestricted();
        }
        if ($.transferMode == TransferMode.CONTROLLED) {
            if (from != $.transferController && to != $.transferController) {
                revert TransferInvalid();
            }
        }
        super._update(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorizes contract upgrades
     * @param newImplementation The address of the new implementation contract
     * @notice Only accounts with DEFAULT_ADMIN_ROLE can authorize upgrades
     * @custom:security Critical function that controls contract upgradeability
     * @custom:security Only accounts with DEFAULT_ADMIN_ROLE can call this function
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Additional upgrade validation logic can be added here if needed
    }
}