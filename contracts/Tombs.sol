// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Ownable from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract Tombs is Ownable, ERC721URIStorage, Pausable{
    using SafeMath for uint256;

    event Withdraw(address indexed account, uint256 amount);
    event Mint (address indexed tombOwner, uint256 indexed tokenId);
    event EpitaphMinted(address indexed tombOwner, uint256 indexed tokenId);
    event PlotPriceChanged(address indexed owner, uint256 indexed newPrice);
    event PlotDiscarded(address indexed owner, uint256 indexed tokenId);

    uint256 constant MAX_TOMB_SUPPLY = 10000;
    uint256 constant PUBLIC_OFFERING_LIMIT = 9900;

    uint256 internal noOfPlotsMinted = 0;
    uint256 internal noOfPlotsSold = 0;

    uint internal plotPrice = 0.25 ether;

    string tokenName;
    string tokenSymbol;

    uint internal nonce;
    //bool paused;

    address beneficiary = owner();

    struct TombInfo{
        uint256 tokenId;
        string tombType;
        bool hasMinted;
        string username;
        string DOB;
        string epitaph;
    }

    TombInfo[MAX_TOMB_SUPPLY] public tombs;

    //stores who owns which tomb
    mapping(uint => address) plotToOwner;      

    mapping (uint256 => address) internal idToApproval;

    //mapping (address => mapping (address => bool)) internal ownerToOperators;

    mapping(address => uint256[]) internal ownerToPlots;

    //mapping(uint256 => uint256) internal plotToOwnerIndex;

    mapping (address => mapping (address => bool)) private _operatorApprovals;

    mapping (uint => bool) internal plotClaimed;

    mapping (uint256 => bool) internal _epitaphMinted;  

    //mapping (uint256 => TombInfo) private plotIdToTombInfo;

    constructor() ERC721("TOMBS","CT"){
    }
    
   
    //override standard erc721 functions

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address _owner) public view virtual override returns (uint256) {
        require(_owner != address(0), "ERC721: balance query for the zero address");
        return _getOwnerPlotCount(_owner);
    }

    /**
     * @dev See {IERC721-instance.getPlotPrice}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = plotToOwner[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return ERC721.name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return ERC721.symbol();
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {  //might remove validPlot modifier
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return idToApproval[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    // /**
    //  * @dev See {IERC721-safeTransferFrom}.
    //  */
    // function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
    //     safeTransferFrom(from, to, tokenId, "");
    // }

    // /**
    //  * @dev See {IERC721-safeTransferFrom}.
    //  */
    // function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
    //     require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    //     _safeTransfer(from, to, tokenId, _data);
    // }

    // /**
    //  * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
    //  * are aware of the ERC721 protocol to prevent tokens from being forever locked.
    //  *
    //  * `_data` is additional data, it has no specified format and it is sent in call to `to`.
    //  *
    //  * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
    //  * implement alternative mechanisms to perform token transfer, such as signature-based.
    //  *
    //  * Requirements:
    //  *
    //  * - `from` cannot be the zero address.
    //  * - `to` cannot be the zero address.
    //  * - `tokenId` token must exist and be owned by `from`.
    //  * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
    //  *
    //  * Emits a {Transfer} event.
    //  */
    // function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual canTransferPlot(tokenId){
    //     _transfer(from, to, tokenId);
    //     require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    // }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual override returns (bool) {
        return plotToOwner[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    // /**
    //  * @dev Safely mints `tokenId` and transfers it to `to`.
    //  *
    //  * Requirements:
    //  *
    //  * - `tokenId` must not exist.
    //  * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
    //  *
    //  * Emits a {Transfer} event.
    //  */
    // function _safeMint(address to, uint256 tokenId) internal virtual {
    //     _safeMint(to, tokenId, "");
    // }

    // /**
    //  * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
    //  * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
    //  */
    // function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
    //     _mint(to, tokenId);
    //     require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    // }

    function mintPlot(uint _tokenId) external payable whenNotPaused{
        //require (!salePaused, "Sales of plot are temparorily paused.");
        //address payable sender = msg.sender;
        uint price = getPlotPrice();
        require(msg.value >= price, "Insufficient funds to purchase plot");

        if(msg.value > price){
            payable(msg.sender).transfer(msg.value.sub(price));
        }

        payable(beneficiary).transfer(price);

        noOfPlotsSold = noOfPlotsSold.add(1);
        _mint(msg.sender, _tokenId);
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint tokenId) internal virtual override{
        require(noOfPlotsSold <= PUBLIC_OFFERING_LIMIT, "All available plots have been claimed :(");
        require(tokenId <= 10000, "only 10000 plots available");
        require(to != address(0), "ERC721: mint to the zero address");
        require(noOfPlotsMinted <= MAX_TOMB_SUPPLY, "10,000 plots already minted :(");
        require(plotClaimed[tokenId] != true, "this plot has been claimed");

        noOfPlotsMinted = noOfPlotsMinted.add(1);

        //uint tokenId = plotRemaining[_getRandomPlot()];
        //_beforeTokenTransfer(address(0), to, tokenId);
        
        //tombInfo properties
        tombs[tokenId].tokenId = tokenId;

        //set type of tomb
        if(tokenId <= 5001){
            tombs[tokenId].tombType = "tablet";
        }else if(tokenId <= 8001){
            tombs[tokenId].tombType = "small monument";
        }else if(tokenId <= 9501){
            tombs[tokenId].tombType = "medium monument";
        }else if(tokenId <= 9901){
            tombs[tokenId].tombType = "obelisk";
        }else{
            tombs[tokenId].tombType = "large monument";
        }



        //_balances[to] += 1;
        plotToOwner[tokenId] = to;
        ownerToPlots[to].push(tokenId);
        plotClaimed[tokenId] = true;
        
        emit Mint(to, tokenId);
        emit Transfer(address(0), to, tokenId);
    }


    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual override{
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        //_beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        ownerToPlots[from].pop;  
        ownerToPlots[to].push(tokenId);
        plotToOwner[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual override {
        idToApproval[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    //function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override{ }

    // /**
    //  Metadata stuff
    //  */

    // /**
    //  * @dev Returns the token collection name.
    //  */
    // function name() external view returns (string memory);

    // /**
    //  * @dev Returns the token collection symbol.
    //  */
    // function symbol() external view returns (string memory);

    /**
     * CrypToTomb Unique Functions
    */

    // function mintEpitaphInfo (uint256 tokenId, string[3] memry info) public {   //consider not using in smart contract and get from website directly
    //     require(_epitaphMinted[tokenId] == false, "epitaph has already been minted");
    //     // require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
    //     //     "ERC721: approve caller is not owner nor approved for all"
    //     // );
    //     require(_isApprovedOrOwner(msg.sender, tokenId));

    //     // tombs[tokenId-1].name = validateName(info[0]);
    //     // tombs[tokenId-1].DOB = validateName(info[1]);
    //     // tombs[tokenId-1].epitaph = validateEpitaph(info[2]);

    //     _epitaphMinted[tokenId] == true;
    //     emit EpitaphMinted(msg.sender, tokenId);
    // }

    // function validateName (string memory name) public returns (string){

    // }

    // function validateDOB (string memory name) public returns (string){

    // }

    // function validateEpitaph(string memory epitaph) public returns (string){

    // }

 


    function getPlotPrice() public view returns (uint){
        return plotPrice;
    }

    function setPlotPrice(uint256 _price) external onlyOwner{
        plotPrice = _price;
        emit PlotPriceChanged(owner(), _price);
    }

    function ownerMint(uint tokenId, address recipient)  external onlyOwner{
        // require(quantity<=MAX_TOMB_SUPPLY.sub(noOfPlotsMinted), "All plots have been minted");
        // for (uint i = 0; i < quantity; i++){
        //     _mint(recipient);
        // }
        _mint(recipient, tokenId);
    }

    function noOfPlotsRemaining() external view returns (uint256){
        return (PUBLIC_OFFERING_LIMIT.sub(noOfPlotsSold));
    }

    function _getOwnerPlotCount(address _owner) internal view returns (uint256){
        return ownerToPlots[_owner].length;
    }

    function totalPlotsClaimed() external view returns (uint256){
        return noOfPlotsMinted;
    }

    // //incase of any issues, pauses all transcations on the contract 
    // function pauseSaleOfPlot() external onlyOwner{

    // }


    function setTokenURI (uint256 tokenId, string memory _tokenURI) public{
        _setTokenURI(tokenId,_tokenURI);

    }

    //AKA Burn

    function discardPlot(uint tokenId) public{
        require(_isApprovedOrOwner(msg.sender, tokenId));

        address owner = ownerOf(tokenId);

        //_beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        ownerToPlots[owner].pop();
        delete plotToOwner[tokenId];

        emit Transfer(owner, address(0), tokenId);
        emit PlotDiscarded(owner, tokenId);


        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    /**
     * @dev Withdraw ether from this contract (Callable by owner)
    */
    function withdraw() onlyOwner public {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function getTombInfo(uint plotId) public view returns (uint256 tokenId, string memory tombType, bool hasMinted, string memory username, string memory DOB, string memory epitaph){
        //add check to ensure it exists
        TombInfo storage tombInfo = tombs[plotId];
        return(tombInfo.tokenId, tombInfo.tombType, tombInfo.hasMinted, tombInfo.username, tombInfo.DOB, tombInfo.epitaph);
    }

    
    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pausePlotSale() public virtual onlyOwner{
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    
    function unpausePlotSale() public virtual onlyOwner{
        _unpause();
    }
    
   
}