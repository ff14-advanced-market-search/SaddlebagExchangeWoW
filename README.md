# wow-addon

https://www.curseforge.com/wow/addons/saddlebag-exchange

## WIP

To download the addon clone the repo locally or [download it as a zip file](https://github.com/ff14-advanced-market-search/SaddlebagExchangeWoW/archive/refs/heads/main.zip).

1. Copy the `SaddlebagExchangeWoW` folder to your `World of Warcraft\_retail_\Interface\AddOns\` folder to load the addon into your game. Make sure the name of the folder is `SaddlebagExchangeWoW` and not `SaddlebagExchangeWoW-main` if you downloaded as a zip file.
2. Go to the auction house and view your active auctions
3. Click the `Get Undercut Alert Data` button that pops up when you view the auction house or run the slash command `/sbex`.

Json data similar to the following will be printed to your chat. This is needed for the discord bot to register for undercut alerts:

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
