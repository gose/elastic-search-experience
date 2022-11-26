//= require jquery
//= require rails-ujs

//= Xrequire main

// require_tree .

var animationLock = false;
var searchRunning = false;
var searchComplete = false;
var userTypingTimeoutTimer;
var userTypingTimeoutMilliseconds = 300;
var emptySearchBackspaceKeyCount = 0;
var position = -1;

$(window).on('resize', function(){
  // Adjust the logo position here
  var win = $(this); //this = window
  if (win.height() >= 820) { /* ... */ }
  if (win.width() >= 1280) { /* ... */ }
});

function addKeyboardControls() {
  var $li = $('li');
  position = -1;

  // Unbind previous keydown handlers
  $(document).unbind('keydown');

  $(document).keydown(function(e) {

    if (e.keyCode == 40 || e.keyCode == 38) {
      e.preventDefault();
      // alert(position);

      if (e.keyCode == 40) {
        // ArrowDown
        position++;
      } else {
        // ArrowUp
        if (position == -1) {
          position = $li.length;
        }
        position--;
      }

      if ((position >= $li.length && e.keyCode == 40) ||
          (position == -1 && e.keyCode == 38)) {
        position = -1;
        $("#search").focus();
      } else {
        $li.eq(position).find('.result').focus();
      }
    }

  });
}

function prepareSearch() {
  if (userTypingTimeoutTimer) {
    clearTimeout(userTypingTimeoutTimer);
  }
  userTypingTimeoutTimer = setTimeout(function() {
    var index = window.location.pathname.split("/").pop();
    if ($("#search").val().length > 0) {
      if (!searchRunning) {
        searchRunning = true;
        searchComplete = false;
        runSearch();
      }
    } else if (index != "") {
      runSearch();
    } else {
      resetSearch();
    }
  }, userTypingTimeoutMilliseconds);
}

function runSearch(href) {
  clearTimeout(userTypingTimeoutTimer);
  $("body").addClass("active-search");
  $(".loading-icon").css("display", "block");
  $(".search-ui-container").css("opacity", "0.3");
  $(".index-toc").fadeOut(50);
  if ($("#logo").css("top") != "0px" && !animationLock) {
    animationLock = true;
    $("#logo").fadeOut(100, function () {
      $("#logo").css("top", "0");
      $("#logo").css("left", "0");
      $("#logo").css("margin", "0");
      $(".brand span").css("font-size", "2.0rem");
      $(".brand small").css("font-size", "1.15rem");
      $(".brand img").css("width", "160px");
    });
    $("#logo").fadeIn(450, function() { animationLock = false; });
  }
  var url = "";
  if (href) {
    url = href;
  } else {
    var index = window.location.pathname.split("/").pop();
    var urlParams = new URLSearchParams(window.location.search);
    var params = [];
    if ($("#search").val()) {
      if ($("#search").val().endsWith(":")) {
        var x = $("#search").val().split(":");
        index = x[0].trim();
        if (x[1].trim() != "") {
          params.push("q=" + x[1].trim());
        }
      } else {
        params.push("q=" + $("#search").val().trim());
      }
    }
    if (urlParams.has('filters')) {
      params.push("filters=" + urlParams.get('filters'));
    }
    if (index == "") {
      index = "all"
    }
    url = "/search/" + index;
    if (params.length > 0) {
      url += "?" + params.join("&");
    }
  }
  Rails.ajax({
    url: url,
    type: "GET",
    data: {},
    success: function(data) {
      searchRunning = false;
      searchComplete = true;
      history.pushState({}, "", url)
      $(".loading-icon").css("display", "none");
      $(".search-ui-container").css("opacity", "1");
      agg_url = url.replace('/search/', '/facets/');
      Rails.ajax({
        url: agg_url,
        type: "GET",
        data: {},
        success: function(data) {
        },
        error: function(data) {
        }
      })
      addKeyboardControls();
    },
    error: function(data) {
      searchRunning = false;
      searchComplete = true;
      $(".loading-icon").css("display", "none");
      $(".search-ui-container").css("opacity", "1");
    }
  })
}

function resetSearch() {
  history.pushState({}, "Elastic", "/")
  $("body").removeClass("active-search");
  $(".loading-icon").css("display", "none");
  $(".search-ui-container").css("opacity", "1");
  $(".index-toc").fadeTo("slow", 0.5);
  // Make sure we're not on mobile
  var viewportWidth = $(window).width();
  if ($("#logo").css("top") != "200px" && viewportWidth > 1000 && !animationLock) {
    animationLock = true;
    $("#logo").fadeOut(10, function() {
      $("#logo").css("top", "200px");
      $("#logo").css("left", "32px");
      $("#logo").css("margin", "auto");
      $(".brand span").css("font-size", "3.0rem");
      $(".brand small").css("font-size", "1.75rem");
      $(".brand img").css("width", "220px");
    });
    $("#logo").fadeIn(250, function() { animationLock = false; });
  }
}

// $(document).on('turbolinks:load', function() {
$(document).on('ready', function() {

  $("#search").focus();

  // --------------
  // Catch pop state
  // --------------
  window.onpopstate = function (event) {
    // This isn't working as intended.
    // runSearch(window.location.pathname + location.search);
  }

  // --------------
  // Launchpad
  // --------------

  var launchpad = $("#launchpad"),
		open = function() {
			launchpad.addClass("shown start");
			launchpad.find("nav").addClass("scale-down");
      $("#logo").fadeOut(0);
      $(".app-icon").css("display", "none");
      $(".search-icon").css("display", "none");
		},
		close = function() {
			launchpad
				.removeClass("start")
				.addClass("end");
			launchpad.find("nav")
				.removeClass("scale-down")
				.addClass("scale-up");
			setTimeout(function() {
				launchpad.removeClass("shown end");
				launchpad.find("nav").removeClass("scale-up");
        $("#logo").fadeIn(50);
        $(".app-icon").css("display", "inline-block");
        $(".search-icon").css("display", "inline-block");
			}, 350);
		};

	// Open the launchpad
	$(".open-menu").on("click", open);

	// Close the launchpad when the content is clicked, only if the target is not a link
	$(document).mouseup(function (e) {
		var content = launchpad.find(".content"),
			nav = content.find("nav");

		if (content.is(e.target) || nav.is(e.target)) {
			close();
		}
	});

  // --------------
  // Search
  // --------------

  if (window.location.pathname.startsWith("/search/")) {
    runSearch();
  }

  $(".hero-search #search")
    .on('keydown', function() {
      var key = event.keyCode || event.charCode;
      // Backspace key
      if (key == 8 || key == 46) {
        var index = window.location.pathname.split("/").pop();
        if ($("#search").val().length == 0 && emptySearchBackspaceKeyCount > 2) {
          // If user keeps hitting backspace, then reset to the home page.
          emptySearchBackspaceKeyCount = 0;
          resetSearch();
        } else {
          // The user is within an index, stay there.
          if ($("#search").val().length == 0) {
            emptySearchBackspaceKeyCount += 1;
          }
          prepareSearch();
        }
      } else if (key == '13') {
        // Return key
        event.preventDefault();
        if (!searchRunning) {
          searchRunning = true;
          runSearch();
        }
      } else if (!/[^a-zA-Z]/.test(String.fromCharCode(event.keyCode)) || key == '186') {
        // User typed a letter or a colon, start the timer.
        prepareSearch();
      }
    })

  // --------------------------------------------------
  // Support modal
  // --------------------------------------------------
  $("[data-open-support]").on("click", function(e) {
    e.preventDefault();
    $("body").addClass("active-contact-support");
    $(".contact-support-control").fadeOut();
    $("#subject").focus();
    $("#logo").fadeOut(100);
  });

  $(".close-support").on("click", function(e) {
    $("body").removeClass("active-contact-support");
    $(".contact-support-control").fadeIn();
    $(".form")
      .find("input, textarea")
      .val("");
    $(".form-container")
      .removeClass("loading done")
      .addClass("form-open");
    $("#logo").fadeIn(800);
  });

  $(".support-form input, .support-form textarea")
    .on("focus", function() {
      $(this)
        .parent()
        .addClass("focused");
    })
    .on("blur", function() {
      if ($(this).val().length < 1) {
        $(this)
          .parent()
          .removeClass("focused has-value");
      } else {
        $(this)
          .parent()
          .removeClass("focused")
          .addClass("has-value");
      }
    });

  $(".support-form .button").on("click", function(e) {
    $(".form-container")
      .removeClass("form-open")
      .addClass("loading");
    data = { message: $('#message').val(), email: $('#email').val() };
    Rails.ajax({
      url: '/feedback',
      type: "POST",
      data: jQuery.param(data),
      success: function(data) {
        $(".form")
          .find("input, textarea")
          .val("");
        setTimeout(function() {
          $(".form-container")
            .removeClass("loading")
            .addClass("done");
        }, 1500);
      },
      error: function(data) {
      }
    })
  });

  $(".toggle-preferences").on("click", function(e) {
    $(".toggles").fadeToggle();
  });

});


function setupImageModal() {
  // --------------------------------------------------
  // Image Modal
  // --------------------------------------------------
  var modal = document.getElementById('myModal');
  var images = document.getElementsByClassName('myImages');
  var modalImg = document.getElementById("img01");
  var captionText = document.getElementById("caption");
  for (var i = 0; i < images.length; i++) {
    var img = images[i];
    img.onclick = function(evt) {
      //console.log(evt);
      modal.style.display = "block";
      modalImg.src = this.src;
      captionText.innerHTML = this.alt;
    }
  }

  var span = document.getElementsByClassName("close-modal")[0];

  span.onclick = function() {
    modal.style.display = "none";
    modalImg.style.animation = 'none';
    modalImg.offsetHeight; /* trigger reflow */
    modalImg.style.animation = null;
  }

}
