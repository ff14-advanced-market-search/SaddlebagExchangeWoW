# wow-addon

## WIP

1. Place this in the `World of Warcraft\_retail_\Interface\AddOns\` folder to load the addon into your game.
2. Go to the auction house and view your active auctions
3. Run the slash command `/hiw`

Output example needed for the discord bot:

```json
{
    "homeRealmId": 3678,
    "region": "NA",
    "user_auctions": [
        {"itemID": 52181,"price": 7720},
        {"itemID": 4500,"price": 97400},
        {"itemID": 173242, "price": 900000},
        {"itemID": 189145,"price": 22003000}
    ]
}
```