# frozen_string_literal: true

module LoggerHelper
  def expect_show_options(apply: false)
    value = apply ? "TRUE" : "FALSE"
    expect(logger).to receive(:info).with("Options:", icon: :options).ordered
    expect(logger).to receive(:log).with("  Apply: #{value}").ordered
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_mappings_legend
    expect(logger).to receive(:info).with("Legend:", icon: :legend).ordered
    expect_logger_log_table([
      [Dotsync::Icons.force, "The source will overwrite the destination"],
      [Dotsync::Icons.ignore, "Paths configured to be ignored in the destination"],
      [Dotsync::Icons.invalid, "Invalid paths detected in the source or destination"]
    ])
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_mappings(expected_rows)
    expect(logger).to receive(:info).with("Mappings:", icon: :config).ordered
    expect_logger_log_table(expected_rows)
    expect(logger).to receive(:log).with("").ordered
  end

  private
    def expect_logger_log_table(expected_rows)
      expect(logger).to receive(:log) do |table|
        expect(table).to be_a(Terminal::Table)
        rows_cells = table.rows.map { |row| row.cells.map(&:value) }
        expect(rows_cells).to eq(expected_rows)
      end
    end
end
