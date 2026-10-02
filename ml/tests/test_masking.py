from therapylink_ml.train.masking import IGNORE, find_spans, response_labels

# Stand-ins for the tokenised '<|turn>model\n' and '<turn|>' markers.
START = [90, 91]
END = [99]


def test_supervises_the_assistant_span_and_its_closing_marker():
    ids = [1, 2, *START, 7, 8, 9, *END, 3]
    assert find_spans(ids, START, END) == [(4, 8)]
    assert response_labels(ids, START, END) == [IGNORE, IGNORE, IGNORE, IGNORE, 7, 8, 9, 99, IGNORE]


def test_end_marker_is_supervised_so_the_model_learns_to_stop():
    # Gemma 4's '<turn|>' is its EOS. Leaving it out of the loss trained v11 to never stop talking.
    ids = [1, *START, 5, *END]
    labels = response_labels(ids, START, END)
    assert labels[-1] == END[0]


def test_handles_several_turns():
    ids = [1, *START, 5, *END, 2, *START, 8, 9, *END]
    assert find_spans(ids, START, END) == [(3, 5), (8, 11)]
    labels = response_labels(ids, START, END)
    assert labels[3:5] == [5, 99]
    assert labels[8:11] == [8, 9, 99]
    assert labels[0] == IGNORE and labels[5] == IGNORE and labels[6] == IGNORE


def test_unterminated_final_span_runs_to_the_end():
    # Truncation cuts the closing marker off; the partial reply is still valid supervision.
    ids = [1, *START, 7, 8]
    assert find_spans(ids, START, END) == [(3, 5)]
    assert response_labels(ids, START, END)[3:] == [7, 8]


def test_no_marker_means_nothing_is_supervised():
    ids = [1, 2, 3, 4]
    assert find_spans(ids, START, END) == []
    assert set(response_labels(ids, START, END)) == {IGNORE}


def test_empty_reply_is_not_supervised_even_with_its_marker():
    ids = [1, *START, *END, 2]
    assert find_spans(ids, START, END) == []


def test_labels_are_the_same_length_as_ids():
    ids = [1, *START, 5, 6, *END, 7, *START, 9]
    assert len(response_labels(ids, START, END)) == len(ids)


def test_marker_bytes_inside_the_reply_do_not_start_a_new_span():
    # Scanning resumes after the closing marker, so a stray START inside text can't nest.
    ids = [*START, 5, *END, *START, 7, *END]
    assert find_spans(ids, START, END) == [(2, 4), (6, 8)]
