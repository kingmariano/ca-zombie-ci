import {ethers, run, upgrades} from "hardhat"

async function main() {
	const [deployer] = await ethers.getSigners()

	console.log("Deploying contracts with the account:", deployer.address)

	const Factory = await ethers.getContractFactory("OnChainSymmioVault")
	const contract = await upgrades.deployProxy(Factory, [
		"0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43", //_symmioAddress
		"0xB6d340Af68279326402139C30934317929535D32", //_lpTokenAddress
		"0xB49Cae38c96f6425Ce4A46e8220549C6a13362bE", //_solver or _broker
		ethers.parseEther('0.9'), //_minimumPaybackRatio
		200000, //_depositLimit
		200000,
	], {initializer: "initialize"})
	
	await contract.waitForDeployment()

	const addresses = {
		proxy: await contract.getAddress(),
		admin: await upgrades.erc1967.getAdminAddress(await contract.getAddress()),
		implementation: await upgrades.erc1967.getImplementationAddress(await contract.getAddress()),
	}
	console.log(addresses)

	try {
		console.log("Verifying contract...")
		await new Promise(r => setTimeout(r, 15000))
		await run("verify:verify", {address: addresses.implementation})
		console.log("Contract verified!")
	} catch (e) {
		console.log(e)
	}
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error)
		process.exit(1)
	})
