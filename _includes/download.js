window.onload = function() {
    let bg = document.getElementsByName("way-cooler-bg")[0];
    let grab = document.getElementsByName("wc-grab")[0];

    function update_download() {
        const install = "curl https://way-cooler.github.io/way-cooler-release-i3-default.sh -sSf | sh -s ";
        let bg_checked = bg.checked ? " way-cooler-bg " : "";
        let grab_checked = grab.checked ? " wc-grab " : "";
        let download_link = document.getElementById("download-link");
        download_link.innerHTML = install + bg_checked + grab_checked;
    }
    bg.onchange = update_download;
    grab.onchange = update_download;
    update_download();
};
console.log("hello world");
