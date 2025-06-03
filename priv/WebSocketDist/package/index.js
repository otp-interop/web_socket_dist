import { init } from "./swiftwasm-build/index.js";
const module = await init({});

const encodePromise = (resolve, reject) => {
    if (!globalThis.__WebSocketDistNodePromiseBuffer)
        globalThis.__WebSocketDistNodePromiseBuffer = {};
    if (!globalThis.__WebSocketDistNodePromiseIndex)
        globalThis.__WebSocketDistNodePromiseIndex = 0;

    const resolveId = globalThis.__WebSocketDistNodePromiseIndex++;
    const rejectId = globalThis.__WebSocketDistNodePromiseIndex++;

    globalThis.__WebSocketDistNodePromiseBuffer[resolveId] = (...value) => {
        const result = value.length == 1
            ? resolve(value[0])
            : resolve(value);
        delete globalThis.__WebSocketDistNodePromiseBuffer[resolveId];
        delete globalThis.__WebSocketDistNodePromiseBuffer[rejectId];
        return result;
    };
    globalThis.__WebSocketDistNodePromiseBuffer[rejectId] = (value) => {
        const result = reject(value);
        delete globalThis.__WebSocketDistNodePromiseBuffer[resolveId];
        delete globalThis.__WebSocketDistNodePromiseBuffer[rejectId];
        return result;
    };

    return [resolveId, rejectId];
}

export class Node {
    address = 0;
    promiseIndex = 0;

    constructor(name, cookie) {
        const encoder = new TextEncoder();
        
        const nameEncoded = encoder.encode(name);
        const cookieEncoded = encoder.encode(cookie);
        
        const nameAddress = module.instance.exports.allocate(nameEncoded.length);
        const cookieAddress = module.instance.exports.allocate(cookieEncoded.length);
        
        try {
            (new Uint8Array(module.instance.exports.memory.buffer, nameAddress)).set(nameEncoded);
            (new Uint8Array(module.instance.exports.memory.buffer, cookieAddress)).set(cookieEncoded);
            const result = module.instance.exports.Node_init(nameAddress, nameEncoded.length, cookieAddress, cookieEncoded.length);
            this.address = result;
        } finally {
            module.instance.exports.deallocate(nameAddress);
            module.instance.exports.deallocate(cookieAddress);
        }
    }

    async connect(peer, name) {
        const encoder = new TextEncoder();
        
        const peerEncoded = encoder.encode(peer);
        const nameEncoded = encoder.encode(name);
        
        const peerAddress = module.instance.exports.allocate(peerEncoded.length);
        const nameAddress = module.instance.exports.allocate(nameEncoded.length);
        
        const connection = await new Promise((resolve, reject) => {
            const [resolveId, rejectId] = encodePromise(resolve, reject);
            try {
                (new Uint8Array(module.instance.exports.memory.buffer, peerAddress)).set(peerEncoded);
                (new Uint8Array(module.instance.exports.memory.buffer, nameAddress)).set(nameEncoded);
                module.instance.exports.Node_connect(
                    this.address,
                    peerAddress, peerEncoded.length,
                    nameAddress, nameEncoded.length,
                    resolveId,
                    rejectId
                );
            } finally {
                module.instance.exports.deallocate(peerAddress);
                module.instance.exports.deallocate(nameAddress);
            }
        });
        return new Connection(connection);
    }
}

export class Connection {
    address = 0;

    constructor(address) {
        this.address = address;
    }

    send(registeredName, term) {
        const encoder = new TextEncoder();

        const registeredNameEncoded = encoder.encode(registeredName);

        const termAddress = module.instance.exports.allocate(term.length);
        const registeredNameAddress = module.instance.exports.allocate(registeredNameEncoded.length);

        try {
            (new Uint8Array(module.instance.exports.memory.buffer, termAddress)).set(term);
            (new Uint8Array(module.instance.exports.memory.buffer, registeredNameAddress)).set(registeredNameEncoded);
            module.instance.exports.Connection_send(
                this.address,
                termAddress, term.length,
                registeredNameAddress, registeredNameEncoded.length
            );
        } finally {
            module.instance.exports.deallocate(termAddress);
            module.instance.exports.deallocate(registeredNameAddress);
        }
    }

    async receive() {
        const promise = new Promise((resolve, reject) => {
            const [resolveId, rejectId] = encodePromise(resolve, reject);

            module.instance.exports.Connection_receive(
                this.address,
                resolveId, rejectId
            );
        });

        return await promise;
    }
}