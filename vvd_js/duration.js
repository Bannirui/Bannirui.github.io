!(function() {
    /* 建站时间 */
  var start = new Date("2023/02/27 24:00:00");

  function update() {
    var now = new Date();
    now.setTime(now.getTime()+250);
    days = (now - start) / 1000 / 60 / 60 / 24;
    dnum = Math.floor(days);
    hours = (now - start) / 1000 / 60 / 60 - (24 * dnum);
    hnum = Math.floor(hours);
    if(String(hnum).length === 1 ){
      hnum = "0" + hnum;
    }
    minutes = (now - start) / 1000 /60 - (24 * 60 * dnum) - (60 * hnum);
    mnum = Math.floor(minutes);
    if(String(mnum).length === 1 ){
      mnum = "0" + mnum;
    }
    seconds = (now - start) / 1000 - (24 * 60 * 60 * dnum) - (60 * 60 * hnum) - (60 * mnum);
    snum = Math.round(seconds);
    if(String(snum).length === 1 ){
      snum = "0" + snum;
    }
    document.getElementById("timeDate").innerHTML = "本站安全运行&nbsp"+dnum+"&nbsp天";
    document.getElementById("times").innerHTML = hnum + "&nbsp小时&nbsp" + mnum + "&nbsp分&nbsp" + snum + "&nbsp秒";
  }

  update();
  setInterval(update, 1000);
})();

<div id="gitalk-container"></div>
<script src="https://cdn.bootcss.com/blueimp-md5/2.12.0/js/md5.min.js"></script><link rel="stylesheet" href="https://unpkg.com/gitalk/dist/gitalk.css"><script src="https://unpkg.com/gitalk/dist/gitalk.min.js"></script>

		<script>
		var gitalkConfig = {"clientID":"7045d14418805a2028d8","clientSecret":"1631bb54c4a78f35ba07c1d35af98e8057babde9","repo":"Bannirui.github.io","owner":"Bannirui","admin":"Bannirui","distractionFreeMode":false};
	    gitalkConfig.id = md5(location.pathname);
		var gitalk = new Gitalk(gitalkConfig);
	    gitalk.render("gitalk-container");
	    </script>