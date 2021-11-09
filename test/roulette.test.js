const Roulette = artifacts.require("Roulette");
const LinkToken = artifacts.require("LinkToken");

contract("Roulette", (accounts) => {
  let instance;
  let owner;

  beforeEach(async () => {
    instance = await Roulette.new();
    owner = await instance.owner();
    await web3.eth.sendTransaction({
      to: instance.address,
      from: accounts[0],
      value: web3.utils.toWei("1", "ether"),
    });
  });
});
