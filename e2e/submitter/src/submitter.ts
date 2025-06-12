// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-nocheck
import * as fs from 'fs/promises';
import * as path from 'path';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';
import dotenv from 'dotenv';
import { SerialTransactionExecutor } from '@mysten/sui/transactions';
import { bcs } from "@mysten/bcs";
dotenv.config();

const CONFIG_FILE_PATH = './config.json';
const BATCH_SIZE = 40;


const SUI_RPC_URL = process.env.SUI_RPC_URL || getFullnodeUrl('localnet');
interface AppConfig {
	packageId: string;
	lcObjectId: string;
	moduleName: string;
	functionName: string;
	headersBinPath: string;
	expectedHeadHeight: number;
}

async function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

async function loadConfig(): Promise<AppConfig> {
	console.log(`Loading config from ${path.resolve(CONFIG_FILE_PATH)}`);
	const configFileContent = await fs.readFile(path.resolve(CONFIG_FILE_PATH), 'utf-8');
	const configData = JSON.parse(configFileContent);

	if (!configData.lc_package_id || !configData.lc_object_id || !configData.headers_bin_path || configData.expected_head_height == null) {
		throw new Error("config.json incorrect");
	}

	return {
		packageId: configData.lc_package_id,
		lcObjectId: configData.lc_object_id,
		headersBinPath: configData.headers_bin_path,
		expectedHeadHeight: configData.expected_head_height,
		moduleName: "light_client",
		functionName: "insert_headers",
	};
}

async function loadHeaders(path: string): Promise<Buffer[]> {
	const rawData = await fs.readFile(path);
	const headers: Buffer[] = [];
	const headerSize = 80;

	for (let i = 0; i + headerSize <= rawData.length; i += headerSize) {
		headers.push(rawData.subarray(i, i + headerSize));
	}
	return headers;
}

async function submitHeaders() {

	try {
		const config = await loadConfig();
		const allHeaders = await loadHeaders(config.headersBinPath);

		if (allHeaders.length === 0) {
			console.log("No headers to submit.");
			return;
		}

		const client = new SuiClient({ url: SUI_RPC_URL });


		const mnemonic = process.env.SUI_SIGNER_MNEMONIC;
		if (!mnemonic) {
			throw new Error(
				"SUI_SIGNER_MNEMONIC environment variable not set. " +
				"Please provide the mnemonic for the gas account."
			);
		}
		const keypair = Ed25519Keypair.deriveKeypair(mnemonic);
		const signerAddress = keypair.getPublicKey().toSuiAddress();

		let submittedCount = 0;

		const executor = new SerialTransactionExecutor({
			client,
			signer: keypair,
		});

		for (let i = 0; i < allHeaders.length; i += BATCH_SIZE) {
			const batch = allHeaders.slice(i, i + BATCH_SIZE);
			if (batch.length === 0) {
				continue;
			}
			const batchNumber = Math.floor(i / BATCH_SIZE) + 1;
			console.log(`\nProcessing Batch #${batchNumber} (Headers ${i + 1} to ${i + batch.length})...`);

			const arrayOfByteArrays = batch.map(buffer => Array.from(buffer));
			const tx = new Transaction();
			tx.moveCall({
				target: `${config.packageId}::${config.moduleName}::${config.functionName}`,
				arguments: [
					tx.object(config.lcObjectId),
					tx.pure('vector<vector<u8>>', arrayOfByteArrays)
				],
			});
			tx.setGasBudget(1000000000);

			const result = await executor.executeTransaction(tx, {
				showEffects: true,
				showObjectChanges: true
			})

			if (result.data.effects?.status?.status === 'success') {
				console.log(`   Status: Success`);
				submittedCount += batch.length;
			} else {
				console.error(`   Status: ${result.data.effects?.status?.status}`);
				console.error(`   Error (if any): ${result.data.effects?.status?.error}`);
			}
		}
	} catch (error) {
		console.error("Error during submitHeaders execution:");
		if (error instanceof Error) {
			console.error(`Message: ${error.message}`);
			console.error(`Stack: ${error.stack}`);
		} else {
			console.error(error);
		}
		throw error;
	}
}

async function checkHeadHeight() {
	try {
		const config = await loadConfig();
		const client = new SuiClient({ url: SUI_RPC_URL });

		const tx = new Transaction();
		tx.moveCall({
			target: `${config.packageId}::${config.moduleName}::head_height`,
			arguments: [tx.object(config.lcObjectId)],
		});

		const result = await client.devInspectTransactionBlock({
			sender: '0x0000000000000000000000000000000000000000000000000000000000000000',
			transactionBlock: tx,
		});

		if (result.effects.status.status !== 'success') {
			throw new Error(`devInspect failed`);
		}

		const returnValue = result.results?.[0]?.returnValues?.[0];
		if (!returnValue) {
			throw new Error("No return value");
		}
		const actualHeight = bcs.u64().parse(new Uint8Array(returnValue[0])).toString();

		console.log(`Expected Head Height: ${config.expectedHeadHeight}`);
		console.log(`Actual Head Height:   ${actualHeight}`);

		if (Number(actualHeight) === config.expectedHeadHeight) {
			console.log("Success: e2e test passed");
		} else {
			console.error(`Failure: Actual height (${actualHeight}) not match the expected height (${config.expectedHeadHeight}).`);
			throw new Error("Head height mismatch.");
		}

	} catch (error) {
		console.error("Error during checkHeadHeight execution:");
		if (error instanceof Error) {
			console.error(`Message: ${error.message}`);
		} else {
			console.error(error);
		}
		throw error;
	}
}

async function main() {
	try {
		await submitHeaders();
		await sleep(1000);
		await checkHeadHeight();
	} catch (error) {
		process.exit(1);
	}
}

main();
