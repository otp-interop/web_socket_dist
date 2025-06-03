export class Node {
    constructor(name: string, cookie: string);
    async connect(peer: string, name: string): Promise<Connection>;
}

export class Connection {
    send(registeredName: string, message: Uint8Array): void;
    async receive(): Promise<Uint8Array>;
}