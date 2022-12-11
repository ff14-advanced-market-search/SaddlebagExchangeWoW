# wow-addon

## WIP

1. Place this in the `World of Warcraft\_retail_\Interface\AddOns\` folder to load the addon into your game.
2. Go to the auction house and view your active auctions
3. Run the slash command `/hiw`

Output example needed for the discord bot:

```json
{
    "homeRealmName": "Thrall",
    "region": "US",
    "user_auctions": [
        {"itemID": 194683,"price": 39900},
        {"itemID": 193210,"price": 54200}
    ]
}
```

4. Then you will copy that json output to your clipboard and send it to the discord bot.  We recommend the [Chat Copy Paste addon](https://www.curseforge.com/wow/addons/chat-copy-paste) to make this easy.