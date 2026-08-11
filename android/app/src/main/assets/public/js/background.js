const extensionApi = globalThis.browser || globalThis.chrome;

extensionApi.action.onClicked.addListener(() => {
  const openedTab = extensionApi.tabs.create({
    url: extensionApi.runtime.getURL("game/index.html")
  });

  if (openedTab && typeof openedTab.catch === "function") {
    openedTab.catch(error => {
      console.error("Unable to open Flag Game:", error);
    });
  }
});
