let start = performance.now();
setInterval(() => {
    let elapsed = ((performance.now() - start) / 1000).toFixed(1);
    const timerElem = document.getElementById("timer");
    if (timerElem) timerElem.innerText = elapsed + "s";
}, 100);

function testPing() {
    const log = document.getElementById("log");
    log.innerText = `Пакет обработан RSMC в ${new Date().toLocaleTimeString()}`;
}
