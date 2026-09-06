// ============================================================
// What customers have been asking the AI hardware consultant, and what
// it said back. Staff read this to see where the answers fall short.
//
// The shop front can add a line to chatbot_logs and can never read one.
// That is not a rule this page enforces — it is two policies on the
// table, one allowing anyone to insert and one allowing only staff to
// select. So a page like this is the only way these ever get read, and
// there is no version of the shop front that could be talked into
// showing somebody else's conversation.
// ============================================================

const LOGS_PER_PAGE = 30;

adminPage("Chatbot Logs", "chatlogs", async (content) => {
  const q = params();
  const only = ["builds", "general"].includes(q.only) ? q.only : "";
  let page = Math.max(1, Number(q.page || 1));

  const filtered = () => {
    let query = sb.from("admin_chat_logs")
      .select("log_id,question,answer,was_build_request,created_at,customer_name",
              { count: "exact" });
    if (only === "builds")  query = query.eq("was_build_request", 1);
    if (only === "general") query = query.eq("was_build_request", 0);
    return query;
  };

  const [listed, allCount, buildCount] = await Promise.all([
    filtered().order("created_at", { ascending: false })
      .range((page - 1) * LOGS_PER_PAGE, page * LOGS_PER_PAGE - 1),
    countOf(sb.from("chatbot_logs").select("log_id", { count: "exact", head: true })),
    countOf(sb.from("chatbot_logs").select("log_id", { count: "exact", head: true })
      .eq("was_build_request", 1)),
  ]);

  if (listed.error) throw listed.error;
  const logs = listed.data;
  const pages = Math.max(1, Math.ceil(listed.count / LOGS_PER_PAGE));

  content.innerHTML = `
    <div class="tiles">
      <div class="tile">
        <div class="label">Questions asked</div>
        <div class="value">${count(allCount)}</div>
      </div>
      <div class="tile">
        <div class="label">Asked for a full build</div>
        <div class="value">${count(buildCount)}</div>
        <div class="sub">${allCount > 0 ? Math.round(buildCount / allCount * 100) : 0}% of all questions</div>
      </div>
    </div>

    <div class="filters">
      <a href="chatlogs.html" class="btn ${only === "" ? "" : "grey"}">All</a>
      <a href="chatlogs.html?only=builds"  class="btn ${only === "builds"  ? "" : "grey"}">Build requests</a>
      <a href="chatlogs.html?only=general" class="btn ${only === "general" ? "" : "grey"}">General questions</a>
    </div>

    <div class="table-wrap">
    <table class="data">
      <thead>
        <tr><th>When</th><th>Customer</th><th>Question &amp; answer</th><th></th></tr>
      </thead>
      <tbody>
      ${logs.length === 0
        ? `<tr><td colspan="4" style="text-align:center; color:#888; padding:26px;">
             Nothing logged yet. Questions appear here as customers use the chatbot on the shop.
           </td></tr>`
        : logs.map((l) => `
        <tr>
          <td style="white-space:nowrap;"><small>${e(when(l.created_at))}</small></td>
          <td><small>${e(l.customer_name || "Not signed in")}</small></td>
          <td>
            <div class="chat-q">${e(l.question)}</div>
            <div class="chat-a">${e(shorten(l.answer, 260))}</div>
          </td>
          <td>
            ${l.was_build_request === 1
              ? '<span class="badge in">Build</span>'
              : '<span class="badge grey">Question</span>'}
          </td>
        </tr>`).join("")}
      </tbody>
    </table>
    </div>

    ${pager(page, pages)}`;
});

// head:true asks for the count without the rows, which is what a
// COUNT(*) was for. It is the one aggregate PostgREST does offer.
async function countOf(query) {
  const { count: total, error } = await query;
  if (error) throw error;
  return total || 0;
}
