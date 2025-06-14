async function fetchStatus() {
  const res = await fetch("/status?_=" + new Date().getTime());
  const data = await res.json();
  const container = document.getElementById("host-container");
  container.innerHTML = "";

  Object.entries(data).forEach(([host, info]) => {
    const card = document.createElement("div");
    card.className = "card " + (info.status === "online" ? "online" : "offline");

    const resources = (info.resources || []).map(r => `<div>${r}</div>`).join("");

    card.innerHTML = `
      <h3>${host}</h3>
      <p><strong>状态：</strong>${info.status}</p>
      <div>${resources}</div>
    `;
    container.appendChild(card);
  });
}

// 页面加载时和每 60 秒刷新一次状态
fetchStatus();
setInterval(fetchStatus, 60000);

