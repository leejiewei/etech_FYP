<?php
// ============================================================
// Behaviour tracking and the chatbot transcript.
//
// These are the numbers behind the admin dashboard: every product view
// and basket add feeds the Inventory Velocity score, and every chatbot
// question is kept so staff can see what customers are asking.
//
// The customer connection is granted INSERT on these tables and nothing
// else — the shop front can record what happened but cannot read back
// what other customers have been doing.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

switch (action()) {

    // Someone looked at a product. Worth 1 in the velocity score.
    case 'view': {
        $in  = body();
        $pid = (int) (isset($in['productId']) ? $in['productId'] : 0);
        if ($pid <= 0) fail('No product given.');

        $customerId = currentCustomerId();   // NULL if browsing signed out
        if ($customerId === null) {
            query("INSERT INTO events (product_id, event_type) VALUES (?, 'view')", [$pid], 'i');
        } else {
            query("INSERT INTO events (customer_id, product_id, event_type) VALUES (?, ?, 'view')",
                  [$customerId, $pid], 'ii');
        }
        reply(['ok' => true]);
    }

    // A question put to the AI hardware consultant, and what it said back.
    case 'chat': {
        $in       = body();
        $question = trim(isset($in['question']) ? $in['question'] : '');
        $answer   = trim(isset($in['answer'])   ? $in['answer']   : '');
        $wasBuild = !empty($in['wasBuildRequest']) ? 1 : 0;
        if ($question === '') fail('Nothing to log.');

        // The answer contains formatting, so strip the tags before storing.
        $answer = strip_tags($answer);

        $customerId = currentCustomerId();
        if ($customerId === null) {
            query("INSERT INTO chatbot_logs (question, answer, was_build_request) VALUES (?, ?, ?)",
                  [$question, $answer, $wasBuild], 'ssi');
        } else {
            query("INSERT INTO chatbot_logs (customer_id, question, answer, was_build_request)
                   VALUES (?, ?, ?, ?)",
                  [$customerId, $question, $answer, $wasBuild], 'issi');
        }
        reply(['ok' => true]);
    }

    default:
        fail('Unknown action.');
}
