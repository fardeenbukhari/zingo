const { WebSocketServer } = require('ws');

const wss = new WebSocketServer({ port: 8080 });

const users = new Map();
const intents = new Map();

wss.on('connection', function connection(ws) {
    let userId = null;

    ws.on('message', function message(data) {
        try {
            const msg = JSON.parse(data.toString());

            switch (msg.type) {
                case 'auth':
                    userId = msg.userId;
                    users.set(userId, {
                        id: userId,
                        ws: ws,
                        lat: msg.lat || 0,
                        lng: msg.lng || 0,
                        name: msg.name,
                        avatar: msg.avatar
                    });

                    // Send current state
                    ws.send(JSON.stringify({
                        type: 'init',
                        users: Array.from(users.values()).map(u => ({
                            id: u.id, lat: u.lat, lng: u.lng, name: u.name, avatar: u.avatar
                        })),
                        intents: Array.from(intents.values())
                    }));
                    break;

                case 'update_location':
                    if (userId && users.has(userId)) {
                        const user = users.get(userId);
                        user.lat = msg.lat;
                        user.lng = msg.lng;

                        // Broadcast to everyone else
                        broadcast({
                            type: 'user_moved',
                            user: { id: userId, lat: msg.lat, lng: msg.lng, name: user.name, avatar: user.avatar }
                        }, userId);
                    }
                    break;

                case 'create_intent':
                    const newIntent = msg.intent;
                    intents.set(newIntent.intentId, newIntent);
                    broadcast({
                        type: 'intent_created',
                        intent: newIntent
                    }, userId);
                    break;
            }
        } catch (e) {
            console.error(e);
        }
    });

    ws.on('close', () => {
        if (userId) {
            users.delete(userId);
            broadcast({
                type: 'user_disconnected',
                userId: userId
            });
        }
    });
});

function broadcast(msg, excludeId = null) {
    const msgStr = JSON.stringify(msg);
    for (const [id, user] of users) {
        if (id !== excludeId && user.ws.readyState === 1 /* OPEN */) {
            user.ws.send(msgStr);
        }
    }
}

console.log('Zingo WebSocket server running on ws://0.0.0.0:8080');
