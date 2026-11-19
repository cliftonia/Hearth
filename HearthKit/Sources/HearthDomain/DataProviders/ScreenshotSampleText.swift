// The longer replies of the README's sample chats. Compiled into debug builds for the simulator only, and never
// into a build that ships.
#if DEBUG && targetEnvironment(simulator)
import Foundation

// swiftlint:disable line_length
enum ScreenshotSampleText {
    static let renamePhotos = """
    Use `exiftool`, which reads the date each photo was taken and names the file after it.

    ### 1. Install it

    ```sh
    brew install exiftool
    ```

    ### 2. Rename the photos

    ```sh
    exiftool '-FileName<DateTimeOriginal' \\
      -d '%Y-%m-%d %H.%M.%S%%-c.%%e' ~/Pictures/Trip
    ```

    - `-d` sets the pattern: the date, then the time.
    - `%-c` adds a number when two photos share a second.
    - **Try it on a copy of the folder first.**

    Photos with no date in them keep their names.
    """

    static let sourdoughReport = """
    ## How long a new starter takes

    Most starters made from flour and water become **active in 5 to 10 days** [1][2]. Active means it reliably doubles within 4 to 8 hours of a feed and smells pleasantly sour [3].

    ### What to expect

    | Days | What you see |
    |---|---|
    | 1–2 | A few bubbles, sometimes a quick rise from other bacteria [2] |
    | 3–5 | A quiet spell; the rise stops while the yeast takes over [1] |
    | 5–10 | Steady doubling after each feed [3] |

    ### What speeds it up

    - Warmth: 24–27 °C is ideal; a cold kitchen can add a week [4].
    - Some wholemeal or rye flour in the first feeds [2].
    - Feeding at the same times each day [3].

    It is ready to bake with once it doubles three days in a row [4].
    """

    static let tasmania = """
    March is early autumn in Tasmania: mild days around 20 °C, cool nights, and weather that turns quickly.

    - **Layers**: a T-shirt, a warm fleece and a light down jacket for the evenings.
    - **A rain jacket**: showers come through even on fine days.
    - **Walking shoes** with grip, if you plan on Cradle Mountain or Freycinet.
    - **Sun protection**: the UV is strong even when it feels cool.

    Pack for four seasons in a day and you will be comfortable.
    """

    static let tasmaniaSources = [
        SearchSource(title: "Tasmania in autumn: what to expect", url: URL(string: "https://island-travel.example/autumn")!, snippet: "Mild days and cool nights."),
        SearchSource(title: "What to wear on Tasmania's walking tracks", url: URL(string: "https://parks-guide.example/clothing")!, snippet: "Layers and a rain jacket."),
        SearchSource(title: "March weather averages for Hobart", url: URL(string: "https://weather-notes.example/hobart-march")!, snippet: "Around 20 degrees by day."),
        SearchSource(title: "Sun safety in southern Australia", url: URL(string: "https://sun-smart.example/uv")!, snippet: "The UV index stays high into autumn.")
    ]

    static let sourdoughSources = [
        SearchSource(title: "Starting a sourdough starter, day by day", url: URL(string: "https://bread-notes.example/starter")!, snippet: "Most starters take five to ten days."),
        SearchSource(title: "Why your starter went quiet on day four", url: URL(string: "https://kitchen-science.example/quiet")!, snippet: "The early rise is not the yeast."),
        SearchSource(title: "Is my starter ready?", url: URL(string: "https://bakers-guide.example/ready")!, snippet: "Look for a reliable doubling."),
        SearchSource(title: "Temperature and your starter", url: URL(string: "https://home-baking.example/temperature")!, snippet: "Warmth makes the biggest difference.")
    ]

    static let briefing = """
    **Adelaide today:** sunny, 16 to 27 °C, with a light south-westerly. No rain is expected until Thursday.

    - UV is very high from 9 am; take a hat.
    - Roadworks on the city ring route may slow the morning commute.
    """

    static let tomatoes = """
    In Adelaide, plant tomatoes from **October to December**, once the nights stay above 10 °C.

    - Space plants **50–60 cm apart**, in rows 90 cm apart.
    - Put a stake in at planting so the roots are not disturbed later.
    - Water deeply twice a week rather than a little each day.
    """

    static let meals = """
    1. **Monday:** lemon chicken with greens
    2. **Tuesday:** vegetable fried rice
    3. **Wednesday:** salmon, potatoes and beans
    4. **Thursday:** lentil and spinach curry
    5. **Friday:** homemade pizza
    """

    static let tipCalculator = """
    Here is a small page you can open in any browser.

    ```html
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Tip calculator</title>
      <style>
        body { font-family: -apple-system, system-ui, sans-serif; background: #f4f1ea; margin: 0; display: grid; place-items: center; min-height: 100vh; color: #1d2b26; }
        .card { background: #fff; padding: 28px; border-radius: 20px; box-shadow: 0 8px 24px rgba(0,0,0,.08); width: 260px; }
        h1 { font-size: 20px; margin: 0 0 16px; }
        label { display: block; font-size: 13px; color: #6b746f; margin-top: 12px; }
        input { width: 100%; font-size: 20px; padding: 8px 10px; border: 1px solid #ddd; border-radius: 10px; box-sizing: border-box; }
        .tip { margin-top: 20px; font-size: 32px; font-weight: 700; color: #2c6b5a; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>Tip calculator</h1>
        <label>Bill ($)<input id="bill" type="number" value="84"></label>
        <label>Tip (%)<input id="rate" type="number" value="10"></label>
        <div class="tip" id="tip"></div>
      </div>
      <script>
        const show = () => {
          const tip = bill.valueAsNumber * rate.valueAsNumber / 100;
          document.getElementById('tip').textContent = 'Tip $' + tip.toFixed(2);
        };
        bill.oninput = rate.oninput = show;
        show();
      </script>
    </body>
    </html>
    ```

    Change the bill or the percentage and the tip updates as you type.
    """
}
// swiftlint:enable line_length
#endif
