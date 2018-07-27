# QTApp MUST be called before calling this, or else program will crash
function qt_subplots()
    (win, (ps, pn)) = linked_subplot_grid([1, 7]; titles = ["Song", "Neural"])
    win[:resize](1000, 600)

    vb_n = get_viewbox(pn)
    ax_n = Axis{PQTG}(vb_n)

    vb_s = get_viewbox(ps)
    ax_s = Axis{PQTG}(vb_s)

    win, vb_n, ax_n, vb_s, ax_s
end
