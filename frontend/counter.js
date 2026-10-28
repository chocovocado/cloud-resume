const API_URL = "https://fwx8jq6bmj.execute-api.us-east-1.amazonaws.com/count";

async function updateCounter() {
    const box = document.getElementById("counter");
    const el = document.getElementById("count");
    if(API_URL.includes("YOUR_API_ID")) return;
    try{
        const res = await fetch(API_URL);
        if (!res.ok) throw new Error(res.status);
        const data = await res.json();
        el.textContent = Number(data.count).toLocaleString("en-US");
        box.classList.add("live");
    } catch (err){
        console.error("Counter failed:", err);
    }
}

updateCounter();