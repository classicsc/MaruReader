(() => {
  // ../../brave-core/components/cosmetic_filters/resources/data/procedural_filters.ts
  var W = window;
  var _asHTMLElement = (node) => {
    return node instanceof HTMLElement ? node : null;
  };
  var _compileRegEx = (regexText) => {
    const regexParts = regexText.split("/");
    const regexPattern = regexParts[1];
    const regexArgs = regexParts[2];
    const regex = new W.RegExp(regexPattern, regexArgs);
    return regex;
  };
  var _testMatches = (test, value, exact = false) => {
    if (test[0] === "/") {
      return value.match(_compileRegEx(test)) !== null;
    }
    if (test === "") {
      return value.trim() === "";
    }
    if (exact) {
      return value === test;
    }
    return value.includes(test);
  };
  var _extractKeyFromStr = (text) => {
    const quotedTerminator = '"=';
    const unquotedTerminator = "=";
    const isQuotedCase = text[0] === '"';
    const [terminator, needlePosition] = isQuotedCase ? [quotedTerminator, 1] : [unquotedTerminator, 0];
    const indexOfTerminator = text.indexOf(terminator, needlePosition);
    if (indexOfTerminator === -1) {
      let key = text;
      if (isQuotedCase) {
        if (!text.endsWith('"')) {
          throw new Error(`Quoted value '${text}' does not terminate with quote`);
        }
        key = text.slice(1, text.length - 1);
      }
      return [key, void 0];
    }
    const testCaseStr = text.slice(needlePosition, indexOfTerminator);
    const finalNeedlePosition = indexOfTerminator + terminator.length;
    return [testCaseStr, finalNeedlePosition];
  };
  var _extractValueMatchRuleFromStr = (text, uriEncode = false, needlePosition = 0) => {
    const testCaseStr = _extractValueFromStr(text, uriEncode, needlePosition);
    const testCaseFunc = _testMatches.bind(void 0, testCaseStr);
    return testCaseFunc;
  };
  var _extractValueFromStr = (text, uriEncode = false, needlePosition = 0) => {
    const isQuotedCase = text[needlePosition] === '"';
    let endIndex;
    if (isQuotedCase) {
      if (text.at(-1) !== '"') {
        throw new Error(
          `Unable to parse value rule from ${text}. Value rule starts with " but doesn't end with "`
        );
      }
      needlePosition += 1;
      endIndex = text.length - 1;
    } else {
      endIndex = text.length;
    }
    let testCaseStr = text.slice(needlePosition, endIndex);
    if (uriEncode) {
      testCaseStr = testCaseStr.replace(
        /\P{ASCII}/gu,
        (c) => encodeURIComponent(c)
      );
    }
    return testCaseStr;
  };
  var _parseKeyValueMatchRules = (arg) => {
    const [key, needlePos] = _extractKeyFromStr(arg);
    const keyMatchRule = (arg2) => _testMatches(key, arg2, true);
    let valueMatchRule;
    if (needlePos !== void 0) {
      const value = _extractValueFromStr(arg, false, needlePos);
      valueMatchRule = (arg2) => _testMatches(value, arg2, true);
    }
    return [keyMatchRule, valueMatchRule];
  };
  var _parseCSSInstruction = (arg) => {
    const rs = arg.split(":");
    if (rs.length !== 2) {
      throw Error(`Unexpected format for a CSS rule: ${arg}`);
    }
    return [rs[0].trim(), rs[1].trim()];
  };
  var _allOtherSiblings = (element) => {
    if (!element.parentNode) {
      return [];
    }
    const siblings = Array.from(element.parentNode.children);
    const otherHTMLElements = [];
    for (const sib of siblings) {
      if (sib === element) {
        continue;
      }
      const siblingHTMLElement = _asHTMLElement(sib);
      if (siblingHTMLElement !== null) {
        otherHTMLElements.push(siblingHTMLElement);
      }
    }
    return otherHTMLElements;
  };
  var _nextSiblingElement = (element) => {
    if (!element.parentNode) {
      return null;
    }
    const siblings = W.Array.from(element.parentNode.children);
    const indexOfElm = siblings.indexOf(element);
    const nextSibling = siblings[indexOfElm + 1];
    if (nextSibling === void 0) {
      return null;
    }
    return _asHTMLElement(nextSibling);
  };
  var _allChildren = (element) => {
    return W.Array.from(element.children).map((e) => _asHTMLElement(e)).filter((e) => e !== null);
  };
  var _allChildrenRecursive = (element) => {
    return W.Array.from(element.querySelectorAll(":scope *")).map((e) => _asHTMLElement(e)).filter((e) => e !== null);
  };
  var _stripCssOperator = (operator, selector) => {
    if (selector[0] !== operator) {
      throw new Error(
        `Expected to find ${operator} in initial position of "${selector}`
      );
    }
    return selector.replace(operator, "").trimStart();
  };
  var operatorCssSelector = (selector, element) => {
    const trimmedSelector = selector.trimStart();
    if (trimmedSelector.startsWith("+")) {
      const subOperator = _stripCssOperator("+", trimmedSelector);
      if (subOperator === null) {
        return [];
      }
      const nextSibNode = _nextSiblingElement(element);
      if (nextSibNode === null) {
        return [];
      }
      return nextSibNode.matches(subOperator) ? [nextSibNode] : [];
    } else if (trimmedSelector.startsWith("~")) {
      const subOperator = _stripCssOperator("~", trimmedSelector);
      if (subOperator === null) {
        return [];
      }
      const allSiblingNodes = _allOtherSiblings(element);
      return allSiblingNodes.filter((x) => x.matches(subOperator));
    } else if (trimmedSelector.startsWith(">")) {
      const subOperator = _stripCssOperator(">", trimmedSelector);
      if (subOperator === null) {
        return [];
      }
      const allChildNodes = _allChildren(element);
      return allChildNodes.filter((x) => x.matches(subOperator));
    } else if (selector.startsWith(" ")) {
      return Array.from(element.querySelectorAll(":scope " + trimmedSelector));
    }
    if (element.matches(selector)) {
      return [element];
    }
    return [];
  };
  var _hasPlainSelectorCase = (selector, element) => {
    return element.matches(selector) ? [element] : [];
  };
  var _hasProceduralSelectorCase = (selector, element) => {
    const shouldBeGreedy = selector[0]?.type !== "css-selector";
    const initElements = shouldBeGreedy ? _allChildrenRecursive(element) : [element];
    const matches = compileAndApplyProceduralSelector(selector, initElements);
    return matches.length === 0 ? [] : [element];
  };
  var operatorHas = (instruction, element) => {
    if (W.Array.isArray(instruction)) {
      return _hasProceduralSelectorCase(instruction, element);
    } else {
      return _hasPlainSelectorCase(instruction, element);
    }
  };
  var operatorHasText = (instruction, element) => {
    const text = element.innerText;
    const valueTest = _extractValueMatchRuleFromStr(instruction);
    return valueTest(text) ? [element] : [];
  };
  var _notPlainSelectorCase = (selector, element) => {
    return element.matches(selector) ? [] : [element];
  };
  var _notProceduralSelectorCase = (selector, element) => {
    const matches = compileAndApplyProceduralSelector(selector, [element]);
    return matches.length === 0 ? [element] : [];
  };
  var operatorNot = (instruction, element) => {
    if (Array.isArray(instruction)) {
      return _notProceduralSelectorCase(instruction, element);
    } else {
      return _notPlainSelectorCase(instruction, element);
    }
  };
  var operatorMatchesProperty = (instruction, element) => {
    const [keyTest, valueTest] = _parseKeyValueMatchRules(instruction);
    for (const [propName, propValue] of Object.entries(element)) {
      if (!keyTest(propName)) {
        continue;
      }
      if (valueTest !== void 0 && !valueTest(propValue)) {
        continue;
      }
      return [element];
    }
    return [];
  };
  var operatorMinTextLength = (instruction, element) => {
    const minLength = +instruction;
    if (minLength === W.NaN) {
      throw new Error(`min-text-length: Invalid arg, ${instruction}`);
    }
    return element.innerText.trim().length >= minLength ? [element] : [];
  };
  var operatorMatchesAttr = (instruction, element) => {
    const [keyTest, valueTest] = _parseKeyValueMatchRules(instruction);
    for (const attrName of element.getAttributeNames()) {
      if (!keyTest(attrName)) {
        continue;
      }
      const attrValue = element.getAttribute(attrName);
      if (attrValue === null || valueTest !== void 0 && !valueTest(attrValue)) {
        continue;
      }
      return [element];
    }
    return [];
  };
  var operatorMatchesCSS = (beforeOrAfter, cssInstruction, element) => {
    const [cssKey, expectedVal] = _parseCSSInstruction(cssInstruction);
    const elmStyle = W.getComputedStyle(element, beforeOrAfter);
    const styleValue = elmStyle.getPropertyValue(cssKey);
    if (styleValue === void 0) {
      return [];
    }
    let matched;
    if (expectedVal.startsWith("/") && expectedVal.endsWith("/")) {
      matched = styleValue.match(_compileRegEx(expectedVal)) !== null;
    } else {
      matched = expectedVal === styleValue;
    }
    return matched ? [element] : [];
  };
  var operatorMatchesMedia = (instruction, element) => {
    return W.matchMedia(instruction).matches ? [element] : [];
  };
  var operatorMatchesPath = (instruction, element) => {
    const pathAndQuery = W.location.pathname + W.location.search;
    const matchRule = _extractValueMatchRuleFromStr(instruction, true);
    return matchRule(pathAndQuery) ? [element] : [];
  };
  var _upwardIntCase = (intNeedle, element) => {
    if (intNeedle < 1 || intNeedle >= 256) {
      throw new Error(`upward: invalid arg, ${intNeedle}`);
    }
    let currentElement = element;
    while (currentElement !== null && intNeedle > 0) {
      currentElement = currentElement.parentNode;
      intNeedle -= 1;
    }
    if (currentElement === null) {
      return [];
    } else {
      const htmlElement = _asHTMLElement(currentElement);
      return htmlElement === null ? [] : [htmlElement];
    }
  };
  var _upwardProceduralSelectorCase = (selector, element) => {
    const childFilter = compileProceduralSelector(selector);
    let needle = element;
    while (needle !== null) {
      const currentElement = _asHTMLElement(needle);
      if (currentElement === null) {
        break;
      }
      const matches = applyCompiledSelector(childFilter, [currentElement]);
      if (matches.length !== 0) {
        return [currentElement];
      }
      needle = currentElement.parentNode;
    }
    return [];
  };
  var _upwardPlainSelectorCase = (selector, element) => {
    let needle = element;
    while (needle !== null) {
      const currentElement = _asHTMLElement(needle);
      if (currentElement === null) {
        break;
      }
      if (currentElement.matches(selector)) {
        return [currentElement];
      }
      needle = currentElement.parentNode;
    }
    return [];
  };
  var operatorUpward = (instruction, element) => {
    if (W.Number.isInteger(+instruction)) {
      return _upwardIntCase(+instruction, element);
    } else if (W.Array.isArray(instruction)) {
      return _upwardProceduralSelectorCase(instruction, element);
    } else {
      return _upwardPlainSelectorCase(instruction, element);
    }
  };
  var operatorXPath = (instruction, element) => {
    const result = W.document.evaluate(
      instruction,
      element,
      null,
      W.XPathResult.UNORDERED_NODE_ITERATOR_TYPE,
      null
    );
    const matches = [];
    let currentNode;
    while (currentNode = result.iterateNext()) {
      const currentElement = _asHTMLElement(currentNode);
      if (currentElement !== null) {
        matches.push(currentElement);
      }
    }
    return matches;
  };
  var ruleTypeToFuncMap = {
    "contains": operatorHasText,
    "css-selector": operatorCssSelector,
    "has": operatorHas,
    "has-text": operatorHasText,
    "matches-attr": operatorMatchesAttr,
    "matches-css": operatorMatchesCSS.bind(void 0, null),
    "matches-css-after": operatorMatchesCSS.bind(void 0, "::after"),
    "matches-css-before": operatorMatchesCSS.bind(void 0, "::before"),
    "matches-media": operatorMatchesMedia,
    "matches-path": operatorMatchesPath,
    "matches-property": operatorMatchesProperty,
    "min-text-length": operatorMinTextLength,
    "not": operatorNot,
    "upward": operatorUpward,
    "xpath": operatorXPath
  };
  var compileProceduralSelector = (operators) => {
    const outputOperatorList = [];
    for (const operator of operators) {
      const anOperatorFunc = ruleTypeToFuncMap[operator.type];
      const args2 = [operator.arg];
      if (anOperatorFunc === void 0) {
        throw new Error(
          `Not sure what to do with operator of type ${operator.type}`
        );
      }
      outputOperatorList.push({
        type: operator.type,
        func: anOperatorFunc.bind(void 0, ...args2),
        args: args2
      });
    }
    return outputOperatorList;
  };
  var fastPathOperatorTypes = ["matches-media", "matches-path"];
  var _determineInitNodesAndIndex = (selector, initNodes) => {
    let nodesToConsider = [];
    let index = 0;
    const firstOperator = selector[0];
    const firstOperatorType = firstOperator.type;
    const firstArg = firstOperator.args[0];
    if (initNodes !== void 0) {
      nodesToConsider = W.Array.from(initNodes);
    } else if (firstOperatorType === "css-selector") {
      const selector2 = firstArg;
      nodesToConsider = W.Array.from(W.document.querySelectorAll(selector2));
      index += 1;
    } else if (firstOperatorType === "xpath") {
      const xpath = firstArg;
      nodesToConsider = operatorXPath(xpath, W.document.documentElement);
      index += 1;
    } else {
      const allNodes = W.Array.from(W.document.all);
      nodesToConsider = allNodes.filter(_asHTMLElement);
    }
    return [index, nodesToConsider];
  };
  var applyCompiledSelector = (selector, initNodes) => {
    const initState = _determineInitNodesAndIndex(selector, initNodes);
    let [index, nodesToConsider] = initState;
    const numOperators = selector.length;
    for (index; nodesToConsider.length > 0 && index < numOperators; ++index) {
      const operator = selector[index];
      const operatorFunc = operator.func;
      const operatorType = operator.type;
      if (fastPathOperatorTypes.includes(operatorType)) {
        const firstNode = nodesToConsider[0];
        if (operatorFunc(firstNode).length === 0) {
          nodesToConsider = [];
        }
        continue;
      }
      let newNodesToConsider = [];
      for (const aNode of nodesToConsider) {
        const result = operatorFunc(aNode);
        newNodesToConsider = newNodesToConsider.concat(result);
      }
      nodesToConsider = newNodesToConsider;
    }
    return nodesToConsider;
  };
  var compileAndApplyProceduralSelector = (selector, initElements) => {
    const compiled = compileProceduralSelector(selector);
    return applyCompiledSelector(compiled, initElements);
  };

  // ../../brave-core/components/cosmetic_filters/resources/data/content_cosmetic_ios.js
  var sendSelectors = $((ids, classes) => {
    return $.postNativeMessage(messageHandler, {
      "securityToken": SECURITY_TOKEN,
      "data": {
        ids,
        classes
      }
    });
  });
  var getPartiness = $((urls) => {
    return $.postNativeMessage(partinessMessageHandler, {
      "securityToken": SECURITY_TOKEN,
      "data": {
        urls
      }
    });
  });
  var throttle = $((func, delay) => {
    let timerId = null;
    return (...args2) => {
      if (timerId === null) {
        func(...args2);
        timerId = setTimeout(() => {
          timerId = null;
        }, delay);
      }
    };
  });
  var timeInMSBeforeStart = 0;
  var minAdTextChars = 30;
  var minAdTextWords = 5;
  var returnToMutationObserverIntervalMs = 1e4;
  var selectorsPollingIntervalMs = 500;
  var selectorsPollingIntervalId;
  var currentMutationScore = 0;
  var scoreCalcIntervalMs = 1e3;
  var currentMutationStartTime = performance.now();
  var notYetQueriedElements = [];
  var classIdWithoutHtmlOrBody = "[id]:not(html):not(body),[class]:not(html):not(body)";
  var generateRandomAttr = () => {
    const min = Number.parseInt("a000000000", 36);
    const max = Number.parseInt("zzzzzzzzzz", 36);
    return Math.floor(Math.random() * (max - min) + min).toString(36);
  };
  var globalStyleAttr = generateRandomAttr();
  var styleAttrMap = /* @__PURE__ */ new Map();
  var CC = {
    allSelectors: /* @__PURE__ */ new Set(),
    pendingSelectors: { ids: /* @__PURE__ */ new Set(), classes: /* @__PURE__ */ new Set() },
    alwaysHiddenSelectors: /* @__PURE__ */ new Set(),
    hiddenSelectors: /* @__PURE__ */ new Set(),
    unhiddenSelectors: /* @__PURE__ */ new Set(),
    allStyleRules: [],
    runQueues: [
      // All new selectors go in this first run queue
      /* @__PURE__ */ new Set(),
      // Third party matches go in the second and third queues.
      /* @__PURE__ */ new Set(),
      // This is the final run queue.
      // It's only evaluated for 1p content one more time.
      /* @__PURE__ */ new Set()
    ],
    // URLS
    pendingOrigins: /* @__PURE__ */ new Set(),
    // A map of origin strings and their isFirstParty results
    urlFirstParty: /* @__PURE__ */ new Map(),
    alreadyKnownFirstPartySubtrees: /* @__PURE__ */ new WeakSet(),
    // All the procedural rules that exist and need to be processed
    // when the script is loaded and a new element is added
    proceduralActionFilters: void 0,
    // Tells us if procedural filtering is available
    hasProceduralActions: false
  };
  var sendPendingOriginsIfNeeded = async () => {
    if (CC.pendingOrigins.size === 0) {
      return false;
    }
    const origins = Array.from(CC.pendingOrigins);
    CC.pendingOrigins = /* @__PURE__ */ new Set();
    const results = await getPartiness(origins);
    for (const origin of origins) {
      const isFirstParty = results[origin];
      if (isFirstParty !== void 0) {
        CC.urlFirstParty[origin] = isFirstParty;
      } else {
        console.error(`Missing partiness for ${origin}`);
      }
    }
    return true;
  };
  var sendPendingSelectorsIfNeeded = async () => {
    for (const elements of notYetQueriedElements) {
      for (const element of elements) {
        extractNewSelectors(element);
      }
    }
    notYetQueriedElements.length = 0;
    if (CC.pendingSelectors.ids.size === 0 && CC.pendingSelectors.classes.size === 0) {
      return;
    }
    const ids = Array.from(CC.pendingSelectors.ids);
    const classes = Array.from(CC.pendingSelectors.classes);
    CC.pendingSelectors.ids = /* @__PURE__ */ new Set();
    CC.pendingSelectors.classes = /* @__PURE__ */ new Set();
    let hasChanges = false;
    const results = await sendSelectors(ids, classes);
    if (results.standardSelectors && results.standardSelectors.length > 0) {
      if (processHideSelectors(
        results.standardSelectors,
        !args.hideFirstPartyContent
      )) {
        hasChanges = true;
      }
    }
    if (results.aggressiveSelectors && results.aggressiveSelectors.length > 0) {
      if (processHideSelectors(results.aggressiveSelectors, false)) {
        hasChanges = true;
      }
    }
    if (!hasChanges) {
      return;
    }
    setRulesOnStylesheetThrottled();
    if (!args.hideFirstPartyContent) {
      pumpCosmeticFilterQueuesOnIdle();
    }
  };
  var sendPendingSelectorsThrottled = throttle(
    sendPendingSelectorsIfNeeded,
    args.fetchNewClassIdRulesThrottlingMs || 200
  );
  var extractIDSelectorIfNeeded = (element) => {
    const id = element.getAttribute("id");
    if (!id) {
      return false;
    }
    if (typeof id !== "string" && !(id instanceof String)) {
      return false;
    }
    const selector = `#${id}`;
    if (!CC.allSelectors.has(selector)) {
      CC.allSelectors.add(selector);
      CC.pendingSelectors.ids.add(id);
      return true;
    } else {
      return false;
    }
  };
  var extractClassSelectorsIfNeeded = (element) => {
    let hasNewSelectors = false;
    for (const className of element.classList) {
      if (!className) {
        continue;
      }
      const selector = `.${className}`;
      if (!CC.allSelectors.has(selector)) {
        CC.pendingSelectors.classes.add(className);
        CC.allSelectors.add(selector);
        hasNewSelectors = true;
      }
    }
    return hasNewSelectors;
  };
  var extractNewSelectors = (element) => {
    if (element.hasAttribute === void 0) {
      return false;
    }
    let hasNewSelectors = false;
    if (element.hasAttribute("id")) {
      hasNewSelectors = extractIDSelectorIfNeeded(element);
    }
    if (extractClassSelectorsIfNeeded(element)) {
      hasNewSelectors = true;
    }
    return hasNewSelectors;
  };
  var extractOriginIfNeeded = (element) => {
    if (args.hideFirstPartyContent || element.hasAttribute === void 0 || !element.hasAttribute("src")) {
      return false;
    }
    const src = element.getAttribute("src");
    isFirstPartyURL(src);
    return true;
  };
  var idleize = (onIdle, timeout) => {
    let idleId;
    return function WillRunOnIdle() {
      if (idleId !== void 0) {
        return;
      }
      idleId = window.setTimeout(() => {
        idleId = void 0;
        onIdle();
      }, timeout);
    };
  };
  var isRelativeUrl = (url) => {
    return !url.startsWith("//") && !url.startsWith("http://") && !url.startsWith("https://");
  };
  var isElement = (node) => {
    return node.nodeType === 1;
  };
  var isHTMLElement = (node) => {
    return "innerText" in node;
  };
  var onMutations = (mutations, observer) => {
    const mutationScore = queueSelectorsFromMutations(mutations);
    if (mutationScore > 0) {
      sendPendingSelectorsThrottled();
    }
    if (args.switchToSelectorsPollingThreshold !== void 0) {
      const now = performance.now();
      if (now > currentMutationStartTime + scoreCalcIntervalMs) {
        currentMutationStartTime = now;
        currentMutationScore = 0;
      }
      currentMutationScore += mutationScore;
      if (currentMutationScore > args.switchToSelectorsPollingThreshold) {
        usePolling(observer);
      }
    }
    if (CC.hasProceduralActions) {
      const addedElements = [];
      mutations.forEach(
        (mutation) => mutation.addedNodes.length !== 0 && mutation.addedNodes.forEach((n) => {
          if (n.nodeType === Node.ELEMENT_NODE) {
            addedElements.push(n);
            const childNodes = n.querySelectorAll("*");
            childNodes.length !== 0 && childNodes.forEach((c) => {
              c.nodeType === Node.ELEMENT_NODE && addedElements.push(c);
            });
          }
        })
      );
      if (addedElements.length !== 0) {
        executeProceduralActions(addedElements);
      }
    }
  };
  var useMutationObserver = () => {
    if (selectorsPollingIntervalId) {
      clearInterval(selectorsPollingIntervalId);
      selectorsPollingIntervalId = void 0;
    }
    const observer = new MutationObserver(onMutations);
    const observerConfig = {
      subtree: true,
      childList: true,
      attributeFilter: ["id", "class"]
    };
    observer.observe(document.documentElement, observerConfig);
  };
  var usePolling = (observer) => {
    if (observer) {
      observer.disconnect();
      notYetQueriedElements.length = 0;
    }
    const futureTimeMs = window.Date.now() + returnToMutationObserverIntervalMs;
    const queryAttrsFromDocumentBound = queryAttrsFromDocument.bind(
      void 0,
      /* switchToMutationObserverAtTime */
      futureTimeMs,
      /* sendSelectorsImmediately */
      false
    );
    selectorsPollingIntervalId = window.setInterval(
      queryAttrsFromDocumentBound,
      selectorsPollingIntervalMs
    );
  };
  var queueSelectorsFromMutations = (mutations) => {
    let mutationScore = 0;
    for (const mutation of mutations) {
      const changedElm = mutation.target;
      switch (mutation.type) {
        case "attributes":
          switch (mutation.attributeName) {
            case "class":
              mutationScore += changedElm.classList.length;
              extractClassSelectorsIfNeeded(changedElm);
              break;
            case "id":
              mutationScore++;
              extractIDSelectorIfNeeded(changedElm);
              break;
          }
          break;
        case "childList":
          for (const node of mutation.addedNodes) {
            if (!isElement(node)) {
              continue;
            }
            notYetQueriedElements.push([node]);
            mutationScore += 1;
            if (node.firstElementChild !== null) {
              const nodeList = node.querySelectorAll(classIdWithoutHtmlOrBody);
              notYetQueriedElements.push(nodeList);
              mutationScore += nodeList.length;
            }
          }
      }
    }
    return mutationScore;
  };
  var extractOriginFromURLString = (urlString) => {
    try {
      const url = new URL(urlString, window.location.toString());
      return url.origin;
    } catch (error) {
      console.error(error);
      return void 0;
    }
  };
  var isFirstPartyURL = (urlString) => {
    if (isRelativeUrl(urlString)) {
      return true;
    }
    const origin = extractOriginFromURLString(urlString);
    if (origin !== void 0) {
      const isFirstParty = CC.urlFirstParty[origin];
      if (isFirstParty === void 0) {
        CC.pendingOrigins.add(origin);
      }
      return isFirstParty;
    } else {
      console.error(`Could not get origin from ${urlString}`);
      return false;
    }
  };
  var stripChildTagsFromText = (elm, tagName, text) => {
    const childElms = Array.from(elm.getElementsByTagName(tagName));
    let localText = text;
    for (let _i = 0, childElms1 = childElms; _i < childElms1.length; _i++) {
      const anElm = childElms1[_i];
      localText = localText.replaceAll(anElm.innerText, "");
    }
    return localText;
  };
  var showsSignificantText = (elm) => {
    if (!isHTMLElement(elm)) {
      return false;
    }
    const htmlElm = elm;
    const tagsTextToIgnore = ["script", "style"];
    let currentText = htmlElm.innerText;
    for (let _i = 0, toIgnore = tagsTextToIgnore; _i < toIgnore.length; _i++) {
      const aTagName = toIgnore[_i];
      currentText = stripChildTagsFromText(htmlElm, aTagName, currentText);
    }
    const trimmedText = currentText.trim();
    if (trimmedText.length < minAdTextChars) {
      return false;
    }
    let wordCount = 0;
    for (let _a = 0, _b = trimmedText.split(" "); _a < _b.length; _a++) {
      const aWord = _b[_a];
      if (aWord.trim().length === 0) {
        continue;
      }
      wordCount += 1;
    }
    return wordCount >= minAdTextWords;
  };
  var subTreePartyInfo = (elm, queryResult) => {
    queryResult = queryResult || {
      foundFirstPartyResource: false,
      foundThirdPartyResource: false,
      foundKnownThirdPartyAd: false,
      pendingSrcAttributes: []
    };
    if (elm.getAttribute) {
      if (elm.hasAttribute("id")) {
        const elmId = elm.getAttribute("id");
        if (elmId.startsWith("google_ads_iframe_") || elmId.startsWith("div-gpt-ad") || elmId.startsWith("adfox_")) {
          queryResult.foundKnownThirdPartyAd = true;
          return queryResult;
        }
      }
      if (elm.hasAttribute("src")) {
        const elmSrc = elm.getAttribute("src");
        const elmSrcIsFirstParty = isFirstPartyURL(elmSrc);
        if (elmSrcIsFirstParty === void 0) {
          queryResult.pendingSrcAttributes.push(elmSrc);
        } else if (elmSrcIsFirstParty) {
          queryResult.foundFirstPartyResource = true;
          return queryResult;
        } else {
          queryResult.foundThirdPartyResource = true;
        }
      }
      if (elm.hasAttribute("style")) {
        const elmStyle = elm.getAttribute("style");
        if (elmStyle.includes("url(") || elmStyle.includes("//")) {
          queryResult.foundThirdPartyResource = true;
        }
      }
      if (elm.hasAttribute("srcdoc")) {
        const elmSrcDoc = elm.getAttribute("srcdoc");
        if (elmSrcDoc.trim() === "") {
          queryResult.foundThirdPartyResource = true;
        }
      }
    }
    const subElms = [];
    if (elm.firstChild) {
      subElms.push(elm.firstChild);
    }
    if (elm.nextSibling) {
      subElms.push(elm.nextSibling);
    }
    for (const subElm of subElms) {
      subTreePartyInfo(subElm, queryResult);
      if (queryResult.foundKnownThirdPartyAd) {
        return queryResult;
      } else if (queryResult.foundFirstPartyResource) {
        return queryResult;
      }
    }
    return queryResult;
  };
  var shouldUnhideElement = (element, pendingSrcAttributes) => {
    const queryResults = subTreePartyInfo(element);
    if (queryResults.foundKnownThirdPartyAd) {
      return false;
    } else if (queryResults.foundFirstPartyResource) {
      return true;
    } else if (showsSignificantText(element)) {
      return true;
    } else if (queryResults.foundThirdPartyResource || queryResults.pendingSrcAttributes.size > 0) {
      if (pendingSrcAttributes !== void 0) {
        queryResults.pendingSrcAttributes.forEach((src) => {
          pendingSrcAttributes.push(src);
        });
      }
      return false;
    }
    return false;
  };
  var shouldUnhideElementAsync = async (element) => {
    const pendingSrcAttributes = [];
    const shouldUnhide = shouldUnhideElement(element, pendingSrcAttributes);
    if (shouldUnhide) {
      return true;
    } else if (pendingSrcAttributes.length > 0) {
      await sendPendingOriginsIfNeeded();
      for (const src of pendingSrcAttributes) {
        if (isFirstPartyURL(src)) {
          return true;
        }
      }
    } else {
      return false;
    }
  };
  var unhideSelectors = (selectors) => {
    if (selectors.size === 0) {
      return;
    }
    Array.from(selectors).forEach((selector) => {
      if (CC.unhiddenSelectors.has(selector)) {
        return;
      }
      CC.hiddenSelectors.delete(selector);
      CC.unhiddenSelectors.add(selector);
      for (let index = 0; index < CC.runQueues.length; index++) {
        CC.runQueues[index].delete(selector);
      }
    });
  };
  var pumpIntervalMinMs = 40;
  var pumpIntervalMaxMs = 100;
  var maxWorkSize = 60;
  var queueIsSleeping = false;
  var pumpCosmeticFilterQueuesOnIdle = idleize(async () => {
    if (queueIsSleeping) {
      return;
    }
    let didPumpAnything = false;
    for (let index = 0; index < CC.runQueues.length; index += 1) {
      const currentQueue = CC.runQueues[index];
      const nextQueue = CC.runQueues[index + 1];
      if (currentQueue.size === 0) {
        continue;
      }
      const currentWorkLoad = Array.from(currentQueue.values()).slice(
        0,
        maxWorkSize
      );
      const comboSelector = currentWorkLoad.join(",");
      const matchingElms = document.querySelectorAll(comboSelector);
      for (const aMatchingElm of matchingElms) {
        if (CC.alreadyKnownFirstPartySubtrees.has(aMatchingElm)) {
          continue;
        }
        const shouldUnhide = await shouldUnhideElementAsync(aMatchingElm);
        if (!shouldUnhide) {
          continue;
        }
        for (const selector of currentWorkLoad) {
          if (!aMatchingElm.matches(selector)) {
            continue;
          }
          if (CC.hiddenSelectors.has(selector) || !CC.unhiddenSelectors.has(selector)) {
            CC.unhiddenSelectors.add(selector);
            CC.hiddenSelectors.delete(selector);
          }
        }
        CC.alreadyKnownFirstPartySubtrees.add(aMatchingElm);
      }
      for (const selector of currentWorkLoad) {
        currentQueue.delete(selector);
        if (nextQueue && !CC.unhiddenSelectors.has(selector)) {
          nextQueue.add(selector);
        }
      }
      didPumpAnything = true;
      break;
    }
    if (!didPumpAnything) {
      return;
    }
    queueIsSleeping = true;
    await sendPendingOriginsIfNeeded();
    setRulesOnStylesheetThrottled();
    window.setTimeout(() => {
      queueIsSleeping = false;
      pumpCosmeticFilterQueuesOnIdle();
    }, pumpIntervalMinMs);
  }, pumpIntervalMaxMs);
  var querySelectorsFromElement = (element) => {
    extractNewSelectors(element);
    const elmWithClassOrId = element.querySelectorAll(classIdWithoutHtmlOrBody);
    elmWithClassOrId.forEach((node) => {
      extractNewSelectors(node);
    });
  };
  var queryAttrsFromDocument = async (switchToMutationObserverAtTime, sendSelectorsImmediately) => {
    querySelectorsFromElement(document);
    if (sendSelectorsImmediately) {
      await sendPendingSelectorsIfNeeded();
    } else {
      sendPendingSelectorsThrottled();
    }
    if (CC.hasProceduralActions) {
      executeProceduralActions();
    }
    if (switchToMutationObserverAtTime !== void 0 && window.Date.now() >= switchToMutationObserverAtTime) {
      useMutationObserver();
    }
  };
  var startPollingSelectors = async () => {
    await queryAttrsFromDocument(
      /* switchToMutationObserverAtTime */
      void 0,
      /* sendSelectorsImmediately */
      true
    );
    useMutationObserver();
  };
  var scheduleQueuePump = (hide1pContent, genericHide) => {
    if (!genericHide || CC.hasProceduralActions) {
      if (args.firstSelectorsPollingDelayMs === void 0) {
        startPollingSelectors();
      } else {
        window.setTimeout(
          startPollingSelectors,
          args.firstSelectorsPollingDelayMs
        );
      }
    }
    if (!hide1pContent) {
      pumpCosmeticFilterQueuesOnIdle();
    }
  };
  var hiddenSelectorsForElement = (element) => {
    if (element.hasAttribute === void 0) {
      return [];
    }
    return Array.from(CC.hiddenSelectors).filter((selector) => {
      try {
        return element.matches(selector);
      } catch (error) {
        CC.hiddenSelectors.delete(selector);
        CC.unhiddenSelectors.add(selector);
        for (let index = 0; index < CC.runQueues.length; index += 1) {
          CC.runQueues[index].delete(selector);
        }
        return false;
      }
    });
  };
  var unhideSelectorsMatchingElementIf1P = (element) => {
    const selectors = hiddenSelectorsForElement(element);
    if (selectors.length === 0) {
      return;
    }
    const shouldUnhide = shouldUnhideElement(element);
    if (!shouldUnhide) {
      return;
    }
    unhideSelectors(selectors);
    return selectors;
  };
  var unhideSelectorsMatchingElementAndItsParents = (node) => {
    const unhiddenSelectors = unhideSelectorsMatchingElementIf1P(node) || [];
    if (node.parentElement && node.parentElement !== document.body) {
      const newSelectors = unhideSelectorsMatchingElementAndItsParents(
        node.parentElement
      );
      for (const selector of newSelectors) {
        unhiddenSelectors.push(selector);
      }
    }
    return unhiddenSelectors;
  };
  var unhideSelectorsMatchingElementsAndTheirParents = (nodes) => {
    const selectorsUnHidden = /* @__PURE__ */ new Set();
    for (const nodeRef of nodes) {
      const node = nodeRef.deref();
      if (node === void 0) {
        return;
      }
      const newSelectors = unhideSelectorsMatchingElementAndItsParents(node);
      for (const selector in newSelectors) {
        selectorsUnHidden.add(selector);
      }
    }
    return selectorsUnHidden.size > 0;
  };
  var onURLMutations = async (mutations, observer) => {
    const elementsWithURLs = [];
    mutations.forEach((mutation) => {
      if (mutation.type === "attributes") {
        const changedElm = mutation.target;
        switch (mutation.attributeName) {
          case "src":
            if (extractOriginIfNeeded(changedElm)) {
              elementsWithURLs.push(new WeakRef(changedElm));
            }
            break;
        }
      } else if (mutation.addedNodes.length > 0) {
        for (const node of mutation.addedNodes) {
          if (!isElement(node)) {
            continue;
          }
          if (extractOriginIfNeeded(node)) {
            elementsWithURLs.push(new WeakRef(node));
          }
        }
      }
    });
    const changes = await sendPendingOriginsIfNeeded();
    if (!changes) {
      return;
    }
    unhideSelectorsMatchingElementIf1P(elementsWithURLs);
    setRulesOnStylesheetThrottled();
  };
  var startURLMutationObserver = () => {
    if (selectorsPollingIntervalId) {
      clearInterval(selectorsPollingIntervalId);
      selectorsPollingIntervalId = void 0;
    }
    const observer = new MutationObserver(onURLMutations);
    const observerConfig = {
      subtree: true,
      childList: true,
      attributeFilter: ["src"]
    };
    observer.observe(document.body, observerConfig);
  };
  var queryURLOriginsInElement = (element) => {
    const possibleAdChildNodes = [];
    const elmWithClassOrId = element.querySelectorAll("[src]");
    elmWithClassOrId.forEach((node) => {
      if (extractOriginIfNeeded(node)) {
        possibleAdChildNodes.push(new WeakRef(node));
      }
    });
    return possibleAdChildNodes;
  };
  var processHideSelectors = (selectors, canUnhide1PElements) => {
    let hasChanges = false;
    selectors.forEach((selector) => {
      if (typeof selector === "string" && !CC.unhiddenSelectors.has(selector)) {
        if (canUnhide1PElements) {
          if (CC.hiddenSelectors.has(selector)) {
            return;
          }
          CC.hiddenSelectors.add(selector);
          CC.runQueues[0].add(selector);
          hasChanges = true;
        } else {
          if (CC.alwaysHiddenSelectors.has(selector)) {
            return;
          }
          CC.alwaysHiddenSelectors.add(selector);
          hasChanges = true;
        }
      }
    });
    return hasChanges;
  };
  var createStylesheet = () => {
    const styleSheetElm = new CSSStyleSheet();
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, styleSheetElm];
    CC.cosmeticStyleSheet = styleSheetElm;
    window.setInterval(() => {
      if (document.adoptedStyleSheets.includes(styleSheetElm)) {
        return;
      }
      document.adoptedStyleSheets = [
        ...document.adoptedStyleSheets,
        styleSheetElm
      ];
    }, 1e3);
  };
  var setRulesOnStylesheet = () => {
    const hideRules = Array.from(CC.hiddenSelectors).map((selector) => {
      return selector + "{display:none !important;}";
    });
    const alwaysHideRules = Array.from(CC.alwaysHiddenSelectors).map(
      (selector) => {
        return selector + "{display:none !important;}";
      }
    );
    const allRules = alwaysHideRules.concat(hideRules.concat(CC.allStyleRules));
    const ruleText = allRules.filter((rule) => {
      return rule !== void 0 && !rule.startsWith(":");
    }).join("");
    CC.cosmeticStyleSheet.replaceSync(ruleText);
  };
  var setRulesOnStylesheetThrottled = throttle(setRulesOnStylesheet, 200);
  var startPolling = async () => {
    if (document.body.contentEditable === "true") {
      return;
    }
    createStylesheet();
    if (!args.hideFirstPartyContent) {
      const nodesWithExtractedURLs = queryURLOriginsInElement(document.body);
      await sendPendingOriginsIfNeeded();
      unhideSelectorsMatchingElementsAndTheirParents(nodesWithExtractedURLs);
    }
    if (CC.hasProceduralActions) {
      executeProceduralActions();
    }
    setRulesOnStylesheet();
    scheduleQueuePump(args.hideFirstPartyContent, args.genericHide);
    if (!args.hideFirstPartyContent) {
      startURLMutationObserver();
    }
  };
  var executeProceduralActions = (added) => {
    if (CC.proceduralActionFilters === void 0) {
      return;
    }
    const getStyleAttr = (style) => {
      let styleAttr = styleAttrMap.get(style);
      if (styleAttr === void 0) {
        styleAttr = generateRandomAttr();
        styleAttrMap.set(style, styleAttr);
        const css = `[${globalStyleAttr}][${styleAttr}]{${style}}`;
        CC.allStyleRules.push(css);
      }
      return styleAttr;
    };
    const performAction = (element, action) => {
      if (action === void 0) {
        const attr = getStyleAttr("display: none !important");
        element.setAttribute(globalStyleAttr, "");
        element.setAttribute(attr, "");
      } else if (action.type === "style") {
        const attr = getStyleAttr(action.arg);
        element.setAttribute(globalStyleAttr, "");
        element.setAttribute(attr, "");
      } else if (action.type === "remove") {
        element.remove();
      } else if (action.type === "remove-attr") {
        element.removeAttribute(action.arg);
      } else if (action.type === "remove-class") {
        if (element.classList.contains(action.arg)) {
          element.classList.remove(action.arg);
        }
      }
    };
    for (const { selector, action } of CC.proceduralActionFilters) {
      try {
        let matchingElements = [];
        let startOperator = 0;
        if (selector[0].type === "css-selector" && added === void 0) {
          matchingElements = document.querySelectorAll(selector[0].arg);
          startOperator = 1;
        } else if (added === void 0) {
          matchingElements = document.querySelectorAll("*");
        } else {
          matchingElements = added;
        }
        if (startOperator === selector.length) {
          matchingElements.forEach((elem) => {
            performAction(elem, action);
          });
        } else {
          const filter = compileProceduralSelector(selector.slice(startOperator));
          applyCompiledSelector(filter, matchingElements).forEach((elem) => {
            performAction(elem, action);
          });
        }
      } catch (e) {
        console.error(
          "Failed to apply filter " + JSON.stringify(selector) + " " + JSON.stringify(action) + ": "
        );
        console.error(e.message);
        console.error(e.stack);
      }
    }
    setRulesOnStylesheetThrottled();
  };
  var waitForBody = () => {
    if (document.body) {
      startPolling();
      return;
    }
    const timerId = window.setInterval(() => {
      if (!document.body) {
        return;
      }
      window.clearInterval(timerId);
      startPolling();
    }, 500);
  };
  if (args.standardSelectors) {
    processHideSelectors(args.standardSelectors, !args.hideFirstPartyContent);
  }
  if (args.aggressiveSelectors) {
    processHideSelectors(args.aggressiveSelectors, false);
  }
  if (proceduralFilters && proceduralFilters.length > 0) {
    CC.proceduralActionFilters = proceduralFilters;
    CC.hasProceduralActions = true;
  }
  window.setTimeout(waitForBody, timeInMSBeforeStart);
})();
