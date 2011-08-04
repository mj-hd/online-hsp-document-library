(function() {
	function main() {
		var divs = toArray(document.getElementsByTagName("div"));
		var opened = false;
		
		for (var i = 0, l = divs.length; i < l; i ++) {
			var div = divs[i];
			if (!div.className) continue;
			if (hasClass(div, "mh1") || hasClass(div, "mh2") || hasClass(div, "mh3")) {
				var a = div.getElementsByTagName("a")[0];
				addEvent(a, "click", headingClickCallback);
			}
			if (!opened && hasClass(div, "mh2")) {
				nextElement(div).style.display = "block";
				opened = true;
			}
		}
		
		var form = document.search_form;
		var input = form.q;
		var suggest_div = document.createElement("div");
		suggest_div.className = "suggest";
		input.setAttribute("autocomplete", "off");
		resizeSuggest(suggest_div, input);
		addEvent(window, "resize", funcBind(resizeSuggest, null, suggest_div, input));
		addEvent(form, "submit", searchFormOnSubmitEvent);
		form.appendChild(suggest_div);
		var suggest = new Suggest.Local(input, suggest_div, OHDL.FunctionList, {highlight: true});
		suggest.onReturn = function() {
			searchFormOnSubmit(form);
			form.submit();
		};
		input.focus();
	}
	
	function searchFormOnSubmitEvent(event) {
		searchFormOnSubmit(event.target || event.srcElement);
	}
	
	function searchFormOnSubmit(form) {
		var input = form.q;
		var m;
		if ((m = /^\s*([#A-Z_a-z][0-9A-Z_a-z]*)\s*$/.exec(input.value))) {
			var word = m[1];
			var uri = OHDL.getReferenceURIByFuncName(word);
			if (uri) {
				window.top.hdlmain.location = uri;
			}
		}
	}
	
	function resizeSuggest(div, input) {
		var position = cumulativeOffset(input);
		var x = position[0], y = position[1];
		var style = div.style;
		style.left = x+"px";
		style.top = (y + input.offsetHeight)+"px";
		style.width = input.offsetWidth+"px";
	}

	function headingClickCallback(event) {
		stopEvent(event);
		var e = nextElement((event.target || event.srcElement).parentNode);
		var ha, hz;
		if (e.style.display == "none") {
			ha = 0;
			e.style.display = "block";
			hz = e.offsetHeight;
		} else {
			ha = e.offsetHeight;
			hz = 0;
		}
		(function animation() {
			if(Math.abs(ha - hz) > 30){
				ha = (ha * 60 + hz * 40) / 100;
				e.style.height = ha + "px";
				e.style.overflow = "hidden";
				e.style.display = "block";
				setTimeout(animation, 1);
			} else {
				e.style.height = "";
				e.style.overflow = "";
				e.style.display = (hz == 0) ? "none" : "block";
			}
		})();
	}

	var addEvent =
	 window.addEventListener ? function(e, n, f) { e.addEventListener(n, f, false); }
	                         : function(e, n, f) { e.attachEvent("on" + n, f); };

	addEvent(window, "load", main);

	function toArray(ary) {
		var len = ary.length;
		var result = Array(len);
		for (var i = 0; i < len; i ++) {
			result[i] = ary[i];
		}
		return result;
	}

	function hasClass(e, className) {
		var s = e.className;
		if (s == className) return true;
		if (!/\s/.test(s)) return false;
		var classes = s.split(/\s+/);
		for (var i = 0, l = classes.length; i < l; i ++) {
			if (classes[i] == className) {
				return true;
			}
		}
		return false;
	}

	function nextElement(e) {
		do {
			e = e.nextSibling;
		} while (e && e.nodeType != 1); // Node.ELEMENT_NODE == 1
		return e;
	}

	function stopEvent(event) {
		if (event.preventDefault) {
			event.preventDefault();
		} else {
			event.returnValue = false;
		}
		if (event.stopPropagation) {
			event.stopPropagation();
		} else {
			event.cancelBubble = true;
		}
	}

	function insertAfter(e1, e2) {
		e1.parentNode.insertBefore(e2, e1.nextSibling);
	}

	function cumulativeOffset(element) {
		var valueT = 0, valueL = 0;
		do {
			valueT += element.offsetTop  || 0;
			valueL += element.offsetLeft || 0;
			element = element.offsetParent;
		} while (element);
		return [valueL, valueT];
	}

	function funcBind(func, thisobj) {
		var args = Array.prototype.slice.call(arguments, 2);
		return function() {
			return func.apply(thisobj, args);
		};
	}
})();
