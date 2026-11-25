# BarScout

> [!Note]
> I fully vibe coded this as a fun experiment and to solve a small problem of mine. Demons may be ahead, you've been warned.

BarScout is a Spotlight-style search for macOS menu bar icons. Press **Option–Space** by default and type the name of an icon or the app it belongs to.

## Run it

BarScout requires macOS 26 or later. Open the project in Bitrig and click **Run**. You can also build it for the Mac preview from the project directory.

```sh
bitrig preview -platform macOS
```

On first launch, follow the setup walkthrough to enable Accessibility and review the search shortcut. You can revisit it from **Show Setup…** in the BarScout menu.

## Use it

- Use **↑** and **↓** to select a result, then press **Return** to open it. You can also click a result.
- Press **Esc** to close the search.
- To change the shortcut, open **Settings** from the BarScout menu bar icon and click the current shortcut. Press the new combination, or choose **Restore Default** to switch back to **Option–Space**.

On macOS 27, icons in the native overflow are searchable while it’s collapsed. Selecting one expands the overflow and opens the item in place. The pointer returns when the item appears. If BarScout expanded the overflow, it collapses it again when the item closes.
