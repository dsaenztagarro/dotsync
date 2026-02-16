# frozen_string_literal: true

module LoggerHelper
  def expect_show_options(apply: false, force_hooks: false)
    value = apply ? "TRUE" : "FALSE"
    expect(logger).to receive(:info).with("Options:", icon: :options).ordered
    expect(logger).to receive(:log).with("  Apply: #{value}").ordered
    expect(logger).to receive(:log).with("  Force hooks: TRUE").ordered if force_hooks
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_mappings_legend
    expect(logger).to receive(:info).with("Mappings Legend:", icon: :legend).ordered
    expect_logger_log_table(Dotsync::MappingsTransfer::MAPPINGS_LEGEND)
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_mappings(expected_rows)
    expect(logger).to receive(:info).with("Mappings:", icon: :config).ordered
    expect_logger_log_table(expected_rows)
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_differences_legend
    expect(logger).to receive(:info).with("Differences Legend:", icon: :legend).ordered
    expect_logger_log_table(Dotsync::MappingsTransfer::DIFFERENCES_LEGEND)
    expect(logger).to receive(:log).with("").ordered
  end

  def expect_show_differences(rows)
    expect(logger).to receive(:info).with("Differences:", icon: :diff).ordered
    rows.each do |row|
      expect(logger).to receive(:log).with(row[:text], color: row[:color]).ordered
    end
  end

  def expect_show_no_differences
    expect(logger).to_not receive(:info).with("Differences Legend:", icon: :legend)
    expect(logger).to receive(:info).with("Differences:", icon: :diff).ordered
    expect(logger).to receive(:log).with("  No differences").ordered
  end

  private
    def expect_logger_log_table(expected_rows)
      expect(logger).to receive(:log) do |table|
        expect(table).to be_a(Terminal::Table)
        rows_cells = table.rows.map { |row| row.cells.map(&:value) }
        expect(rows_cells).to eq(expected_rows)
      end.ordered
    end
end
