// What an application must find again next time it is opened, kept as well as a page can keep it.
//
// A browser has no keystore, so what a page can offer is two things and they are worth saying plainly:
// the store belongs to this origin and nothing served from anywhere else can reach it, and the values in
// it are encrypted with a key the page itself cannot read. The key is generated non-extractable and kept
// in IndexedDB, so what is written to disk is cipher text and a copy of the site data taken off the
// machine is worth nothing without the browser profile it came from. It is not a secure element and the
// documentation says so: a reader who hands their unlocked machine to somebody has handed over the lot.

const DATABASE = "varn-preferences";
const KEYS = "keys";
const VALUES = "values";
const ALIAS = "key";
const NONCE = 12;

export class Preferences {
    constructor() {
        this.opened = undefined;
        this.sealing = undefined;
    }

    // The one database this keeps, opened once however many times it is asked for.
    database() {
        if (this.opened !== undefined) {
            return this.opened;
        }

        this.opened = new Promise((settle, refuse) => {
            const asked = indexedDB.open(DATABASE, 1);

            asked.onupgradeneeded = () => {
                const held = asked.result;

                if (!held.objectStoreNames.contains(KEYS)) {
                    held.createObjectStore(KEYS);
                }

                if (!held.objectStoreNames.contains(VALUES)) {
                    held.createObjectStore(VALUES);
                }
            };

            asked.onsuccess = () => settle(asked.result);
            asked.onerror = () => refuse(asked.error ?? new Error("the browser refused the store"));
        });

        return this.opened;
    }

    async work(store, mode, run) {
        const held = await this.database();

        return new Promise((settle, refuse) => {
            const deal = held.transaction(store, mode);
            const asked = run(deal.objectStore(store));

            deal.onerror = () => refuse(deal.error ?? new Error("the store refused it"));
            asked.onsuccess = () => settle(asked.result);
            asked.onerror = () => refuse(asked.error ?? new Error("the store refused it"));
        });
    }

    // The key the values are sealed with, made the first time it is asked for and never readable after.
    key() {
        if (this.sealing !== undefined) {
            return this.sealing;
        }

        this.sealing = (async () => {
            const held = await this.work(KEYS, "readonly", (store) => store.get(ALIAS));

            if (held !== undefined) {
                return held;
            }

            const made = await crypto.subtle.generateKey(
                { name: "AES-GCM", length: 256 },
                false,
                ["encrypt", "decrypt"],
            );

            await this.work(KEYS, "readwrite", (store) => store.put(made, ALIAS));
            return made;
        })();

        return this.sealing;
    }

    async set(name, value) {
        const nonce = crypto.getRandomValues(new Uint8Array(NONCE));
        const written = new TextEncoder().encode(JSON.stringify([value]));

        const sealed = await crypto.subtle.encrypt(
            { name: "AES-GCM", iv: nonce },
            await this.key(),
            written,
        );

        const carried = new Uint8Array(NONCE + sealed.byteLength);

        carried.set(nonce, 0);
        carried.set(new Uint8Array(sealed), NONCE);

        await this.work(VALUES, "readwrite", (store) => store.put(carried, name));
    }

    async get(name) {
        const carried = await this.work(VALUES, "readonly", (store) => store.get(name));

        if (carried === undefined) {
            return undefined;
        }

        const read = await crypto.subtle.decrypt(
            { name: "AES-GCM", iv: carried.slice(0, NONCE) },
            await this.key(),
            carried.slice(NONCE),
        );

        return JSON.parse(new TextDecoder().decode(read))[0];
    }

    async remove(name) {
        await this.work(VALUES, "readwrite", (store) => store.delete(name));
    }

    async clear() {
        await this.work(VALUES, "readwrite", (store) => store.clear());
    }

    async names() {
        const held = await this.work(VALUES, "readonly", (store) => store.getAllKeys());

        return [...held].sort();
    }
}
