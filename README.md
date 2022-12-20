# wow-addon

https://www.curseforge.com/wow/addons/saddlebag-exchange

# wow api call guide

https://github.com/ff14-advanced-market-search/saddlebag-with-pockets/wiki/API-Call-Guide:-Part-2-(WoW-API)

## Addon JSON Output Example
![image](https://user-images.githubusercontent.com/17516896/208216286-2716b14a-8548-4334-ab5d-17de895938ca.png)

## Discord Alert Example:

<img width="544" alt="Screen Shot 2022-12-20 at 12 30 41 PM" src="https://user-images.githubusercontent.com/17516896/208729833-c89b6853-301d-4415-b67a-79b2507e1b97.png">

## Descirption and Instructions

We are currently working on fixing our curseforge file upload, hold tight and try a direct download for now if you want to try it right now!

To download the addon clone the repo locally or [download it as a zip file](https://github.com/ff14-advanced-market-search/SaddlebagExchangeWoW/archive/refs/heads/main.zip).

1. Copy the `SaddlebagExchangeWoW` folder to your `World of Warcraft\_retail_\Interface\AddOns\` folder to load the addon into your game. Make sure the name of the folder is `SaddlebagExchangeWoW` and not `SaddlebagExchangeWoW-main` if you downloaded as a zip file.
2. Go to the auction house and view your active auctions
3. Click the `Get Undercut Alert Data` button that pops up when you view the auction house or run the slash command `/sbex`.

Json data similar to the following will be printed into the saddlebag popup window:

![image](https://user-images.githubusercontent.com/17516896/208216286-2716b14a-8548-4334-ab5d-17de895938ca.png)

What you copy to your clipboard should look like this:

```json
{
    "homeRealmName": "Thrall",
    "region": "US",
    "user_auctions": [
        {"itemID": 194275,"price": 200000000},
        {"itemID": 197968,"price": 299990000},
        {"itemID": 194276,"price": 399990000},
        {"itemID": 194272,"price": 399990000},
        {"itemID": 192097,"price": 57500},
        {"itemID": 194278,"price": 389990000},
        {"itemID": 194274,"price": 400000000},
        {"itemID": 194312,"price": 48889900}
    ]
}
```

4. Then you will copy that json output to your clipboard and send it to the discord bot.  We recommend the [Chat Copy Paste addon](https://www.curseforge.com/wow/addons/chat-copy-paste) to make this easy.

